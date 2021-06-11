# Event segmentation using a Hidden Markov Model with edits specific for infant data

# This code is based **heavily** on the BrainIAK v0.8 implementation of event segmentation (Copyright 2016 Princeton University)
# https://github.com/brainiak/brainiak/blob/master/brainiak/eventseg/event.py
# Original authors: Chris Baldassano and Cătălin Iordan 
# Princeton University, 2018

# Differences from this script and the BrainIAK implementation include defining certain functions (e.g., masked_log) inside of this file instead of in a separate utils file. The main difference between this file and the BrainIAK event segmentation model is how missing timepoints are dealt with. While the event segmentation model can take as input a list of subject data, we can use the average time series across subjects within a group or iteration in order to speed up the calculation. The v0.8 BrainIAK version of the script would assign the same variance parameter to timepoints that may have had more subjects contributing to the group average, which may not be desirable, since timepoints with data from more subjects can be thought of as more "trustworthy" than other timepoints. Additionally, it did not have a method of dealing with NaNs that persisted after group averaging (which can happen in noisier infant data). To address the first point, we supply an additional input along with the average group time series data to the fit() function of the event segmentation model called nsubj, which is an array with a length corresponding to the number of timepoints and values corresponding to the number of subjects with non-NaN data at each timepoint. In the _logprob_obs() function, this array is used to scale the Gaussian variance used during fitting by the square-root of the maximum number of participants divided by the square-root of the number of participants with data at that point. This differs from the original script, where the variance was assumed to be the same across timepoints during initial model fitting. To address the second point of missing timepoints even after averaging, we also edited the _forward_backward() function to linearly interpolate the log-probability for missing timepoints based on nearby values. Without this edit, the function would fail to find the log probability that each timepoint belongs to each event. These changes are marked as ### Infant specific change ###  
# Authors of modified script: Tristan Yates and Chris Baldassano 
# Yale University, 2020

# Imports
import numpy as np
from scipy import stats
import logging
import copy
from sklearn.base import BaseEstimator
from sklearn.utils.validation import check_is_fitted, check_array
from sklearn.exceptions import NotFittedError


from numpy import log
from numbers import Integral, Real
from typing import TypeVar, Union

T = TypeVar("T", bound=Real)

def masked_log(x):
    """Compute natural logarithm while accepting nonpositive input
    For nonpositive elements, return -inf.
    Output type is the same as input type, except when input is integral, in
    which case output is `np.float64`.
    Parameters
    ----------
    x: ndarray[T]
    Returns
    -------
    ndarray[Union[T, np.float64]]
    """
    if issubclass(x.dtype.type, Integral):
        out_type = np.float64
    else:
        out_type = x.dtype
    y = np.empty(x.shape, dtype=out_type)
    lim = x.shape[0]
    for i in range(lim):
      if x[i] <= 0:
        y[i] = float('-inf')
      else:
        y[i] = log(x[i])
    return y



logger = logging.getLogger(__name__)

__all__ = [
    "EventSegment",
]


class EventSegment(BaseEstimator):
    """Class for event segmentation of continuous fMRI data
    Parameters
    ----------
    n_events: int
        Number of segments to learn
    step_var: Callable[[int], float] : default 4 * (0.98 ** (step - 1))
        The Gaussian variance to use during fitting, as a function of the
        number of steps. Should decrease slowly over time.
    n_iter: int : default 500
        Maximum number of steps to run during fitting
    event_chains: ndarray with length = n_events
        Array with unique value for each separate chain of events, each linked
        in the order they appear in the array
    Attributes
    ----------
    p_start, p_end: length n_events+1 ndarray
        initial and final prior distributions over events
    P: n_events+1 by n_events+1 ndarray
        HMM transition matrix
    ll_ : ndarray with length = number of training datasets
        Log-likelihood for training datasets over the course of training
    segments_:  list of (time by event) ndarrays
        Learned (soft) segmentation for training datasets
    event_var_ : float
        Gaussian variance at the end of learning
    event_pat_ : voxel by event ndarray
        Learned mean patterns for each event
    """

    def _default_var_schedule(step):
        return 4 * (0.98 ** (step - 1))

    def __init__(self, n_events=2,
                 step_var=_default_var_schedule,
                 n_iter=500, event_chains=None):
        self.n_events = n_events
        self.step_var = step_var
        self.n_iter = n_iter
        if event_chains is None:
            self.event_chains = np.zeros(n_events)
        else:
            self.event_chains = event_chains

    def fit(self, nsubj, X, y=None):
        """Learn a segmentation on training data
        Fits event patterns and a segmentation to training data. After
        running this function, the learned event patterns can be used to
        segment other datasets using find_events
        Parameters
        ----------
        nsubj: ndarray of length time, specifying the number of subjects
               used to compute each timepoint
        X: time by voxel ndarray, or a list of such ndarrays
            fMRI data to be segmented. If a list is given, then all datasets
            are segmented simultaneously with the same event patterns
        y: not used (added to comply with BaseEstimator definition)
        Returns

        -------
        self: the EventSegment object
        """

        X = copy.deepcopy(X)
        if type(X) is not list:
            X = check_array(X,force_all_finite=False) # CHANGE HERE
            X = [X]

        n_train = len(X)
        for i in range(n_train):
            X[i] = X[i].T

        self.classes_ = np.arange(self.n_events)
        n_dim = X[0].shape[0]
        for i in range(n_train):
            assert (X[i].shape[0] == n_dim)

        # Double-check that data is z-scored in time
        for i in range(n_train):
            X[i] = stats.zscore(X[i], axis=1, ddof=1)

        # Initialize variables for fitting
        log_gamma = []
        for i in range(n_train):
            log_gamma.append(np.zeros((X[i].shape[1],
                                       self.n_events)))
        step = 1
        best_ll = float("-inf")
        self.ll_ = np.empty((0, n_train))
        while step <= self.n_iter:
            iteration_var = self.step_var(step)

            # Based on the current segmentation, compute the mean pattern
            # for each event
            seg_prob = [np.exp(lg) / np.sum(np.exp(lg), axis=0)
                        for lg in log_gamma]
            mean_pat = np.empty((n_train, n_dim, self.n_events))
            for i in range(n_train):
                mean_pat[i, :, :] = X[i].dot(seg_prob[i])
            mean_pat = np.nanmean(mean_pat, axis=0) 

            # Based on the current mean patterns, compute the event
            # segmentation
            self.ll_ = np.append(self.ll_, np.empty((1, n_train)), axis=0)
            for i in range(n_train):
                logprob = self._logprob_obs(X[i],
                                            mean_pat, iteration_var, nsubj)
                log_gamma[i], self.ll_[-1, i] = self._forward_backward(logprob)

            # If log-likelihood has started decreasing, undo last step and stop
            if np.mean(self.ll_[-1, :]) < best_ll:
                self.ll_ = self.ll_[:-1, :]
                break

            self.segments_ = [np.exp(lg) for lg in log_gamma]
            self.event_var_ = iteration_var
            self.event_pat_ = mean_pat
            best_ll = np.mean(self.ll_[-1, :])
            logger.debug("Fitting step %d, LL=%f", step, best_ll)

            step += 1

        return self

    def _logprob_obs(self, data, mean_pat, var, nsubj):
        """Log probability of observing each timepoint under each event model
        Computes the log probability of each observed timepoint being
        generated by the Gaussian distribution for each event pattern
        Parameters
        ----------
        data: voxel by time ndarray
            fMRI data on which to compute log probabilities
        mean_pat: voxel by event ndarray
            Centers of the Gaussians for each event
        var: float or 1D array of length equal to the number of events
            Variance of the event Gaussians. If scalar, all events are
            assumed to have the same variance
        nsubj: ndarray of length time, specifying the number of subjects
               used to compute each timepoint

        Returns
        -------
        logprob : time by event ndarray
            Log probability of each timepoint under each event Gaussian
        """

        n_vox = data.shape[0]
        t = data.shape[1]

        # z-score both data and mean patterns in space, so that Gaussians
        # are measuring Pearson correlations and are insensitive to overall
        # activity changes
        data_z = stats.zscore(data, axis=0, ddof=1)
        mean_pat_z = stats.zscore(mean_pat, axis=0, ddof=1)

        logprob = np.empty((t, self.n_events))
        
        ### Infant specific change ###
        # Scale the variance by the number of subjects contributing data to that timepoint
        if type(var) is not np.ndarray:
            var = var * np.ones(self.n_events)

        for k in range(self.n_events):
            timepoint_var = var[k] * np.sqrt(np.max(nsubj))/np.sqrt(nsubj)
            logprob[:, k] = -0.5 * n_vox * np.log(
                2 * np.pi * timepoint_var) - 0.5 * np.sum(
                (data_z.T - mean_pat_z[:, k]).T ** 2, axis=0) / timepoint_var

        logprob /= n_vox

       
        return logprob

    def _forward_backward(self, logprob):
        """Runs forward-backward algorithm on observation log probs
        Given the log probability of each timepoint being generated by
        each event, run the HMM forward-backward algorithm to find the
        probability that each timepoint belongs to each event (based on the
        transition priors in p_start, p_end, and P)
        See https://en.wikipedia.org/wiki/Forward-backward_algorithm for
        mathematical details
        Parameters
        ----------
        logprob : time by event ndarray
            Log probability of each timepoint under each event Gaussian
        Returns
        -------
        log_gamma : time by event ndarray
            Log probability of each timepoint belonging to each event
        ll : float
            Log-likelihood of fit
        """
        logprob = copy.copy(logprob)
        t = logprob.shape[0]
        

        ### Infant specific change ###
        # If there are NaNs in the data, you cannot compute the log-likelihood
        # Therefore we will perform a linear interpolation of what the logprob could possible be based on its nearby values
        
        nans=np.isnan(logprob[:,0])
        lin_func=lambda z: z.nonzero()[0]

        for ev in range(logprob.shape[1]):
            logprob[nans,ev]= np.interp(lin_func(nans), lin_func(~nans), logprob[~nans,ev])
 
        
        logprob = np.hstack((logprob, float("-inf") * np.ones((t, 1))))
            
        # Initialize variables
        log_scale = np.zeros(t)
        log_alpha = np.zeros((t, self.n_events + 1))
        log_beta = np.zeros((t, self.n_events + 1))

        # Set up transition matrix, with final sink state
        self.p_start = np.zeros(self.n_events + 1)
        self.p_end = np.zeros(self.n_events + 1)
        self.P = np.zeros((self.n_events + 1, self.n_events + 1))
        label_ind = np.unique(self.event_chains, return_inverse=True)[1]
        n_chains = np.max(label_ind) + 1

        # For each chain of events, link them together and then to sink state
        for c in range(n_chains):
            chain_ind = np.nonzero(label_ind == c)[0]
            self.p_start[chain_ind[0]] = 1 / n_chains
            self.p_end[chain_ind[-1]] = 1 / n_chains

            p_trans = (len(chain_ind) - 1) / t
            if p_trans >= 1:
                raise ValueError('Too few timepoints')
            for i in range(len(chain_ind)):
                self.P[chain_ind[i], chain_ind[i]] = 1 - p_trans
                if i < len(chain_ind) - 1:
                    self.P[chain_ind[i], chain_ind[i+1]] = p_trans
                else:
                    self.P[chain_ind[i], -1] = p_trans
        self.P[-1, -1] = 1

        # Forward pass
        for i in range(t):
            if i == 0:
                log_alpha[0, :] = self._log(self.p_start) + logprob[0, :]
            else:
                log_alpha[i, :] = self._log(np.exp(log_alpha[i - 1, :])
                                            .dot(self.P)) + logprob[i, :]

            log_scale[i] = np.logaddexp.reduce(log_alpha[i, :])
            log_alpha[i] -= log_scale[i]

        # Backward pass
        log_beta[-1, :] = self._log(self.p_end) - log_scale[-1]
        for i in reversed(range(t - 1)):
            obs_weighted = log_beta[i + 1, :] + logprob[i + 1, :]
            offset = np.max(obs_weighted)
            log_beta[i, :] = offset + self._log(
                np.exp(obs_weighted - offset).dot(self.P.T)) - log_scale[i]

        # Combine and normalize
        log_gamma = log_alpha + log_beta
        log_gamma -= np.logaddexp.reduce(log_gamma, axis=1, keepdims=True)

        ll = np.sum(log_scale[:(t - 1)]) + np.logaddexp.reduce(
            log_alpha[-1, :] + log_scale[-1] + self._log(self.p_end))

        log_gamma = log_gamma[:, :-1]

        return log_gamma, ll

    def _log(self, x):
        """Modified version of np.log that manually sets values <=0 to -inf
        Parameters
        ----------
        x: ndarray of floats
            Input to the log function
        Returns
        -------
        log_ma: ndarray of floats
            log of x, with x<=0 values replaced with -inf
        """

        xshape = x.shape
        _x = x.flatten()
        y = masked_log(_x)
        return y.reshape(xshape)

    def set_event_patterns(self, event_pat):
        """Set HMM event patterns manually
        Rather than fitting the event patterns automatically using fit(), this
        function allows them to be set explicitly. They can then be used to
        find corresponding events in a new dataset, using find_events().
        Parameters
        ----------
        event_pat: voxel by event ndarray
        """
        if event_pat.shape[1] != self.n_events:
            raise ValueError(("Number of columns of event_pat must match "
                              "number of events"))
        self.event_pat_ = event_pat.copy()

    def find_events(self, nsubj,testing_data,var=None, scramble=False):
        """Applies learned event segmentation to new testing dataset
        After fitting an event segmentation using fit() or setting event
        patterns directly using set_event_patterns(), this function finds the
        same sequence of event patterns in a new testing dataset.
        Parameters
        ----------
        nsubj: ndarray of length time, specifying the number of subjects
               used to compute each timepoint
        testing_data: timepoint by voxel ndarray
            fMRI data to segment based on previously-learned event patterns
        var: float or 1D ndarray of length equal to the number of events
            default: uses variance that maximized training log-likelihood
            Variance of the event Gaussians. If scalar, all events are
            assumed to have the same variance. If fit() has not previously
            been run, this must be specifed (cannot be None).
        scramble: bool : default False
            If true, the order of the learned events are shuffled before
            fitting, to give a null distribution
        Returns
        -------
        segments : time by event ndarray
            The resulting soft segmentation. segments[t,e] = probability
            that timepoint t is in event e
        test_ll : float
            Log-likelihood of model fit
        """

        if var is None:
            if not hasattr(self, 'event_var_'):
                raise NotFittedError(("Event variance must be provided, if "
                                      "not previously set by fit()"))
            else:
                var = self.event_var_

        if not hasattr(self, 'event_pat_'):
            raise NotFittedError(("The event patterns must first be set "
                                  "by fit() or set_event_patterns()"))
        if scramble:
            mean_pat = self.event_pat_[:, np.random.permutation(self.n_events)]
        else:
            mean_pat = self.event_pat_
        
        logprob = self._logprob_obs(testing_data.T, mean_pat, var, nsubj)
        
        lg, test_ll = self._forward_backward(logprob)
        segments = np.exp(lg)

        return segments, test_ll

    def predict(self, X):
        """Applies learned event segmentation to new testing dataset
        Alternative function for segmenting a new dataset after using
        fit() to learn a sequence of events, to comply with the sklearn
        Classifier interface
        Parameters
        ----------
        X: timepoint by voxel ndarray
            fMRI data to segment based on previously-learned event patterns
        Returns
        -------
        Event label for each timepoint
        """
        check_is_fitted(self, ["event_pat_", "event_var_"])
        X = check_array(X)
        segments, test_ll = self.find_events(X)
        return np.argmax(segments, axis=1)

    def calc_weighted_event_var(self, D, weights, event_pat):
        """Computes normalized weighted variance around event pattern
        Utility function for computing variance in a training set of weighted
        event examples. For each event, the sum of squared differences for all
        timepoints from the event pattern is computed, and then the weights
        specify how much each of these differences contributes to the
        variance (normalized by the number of voxels).
        Parameters
        ----------
        D : timepoint by voxel ndarray
            fMRI data for which to compute event variances
        weights : timepoint by event ndarray
            specifies relative weights of timepoints for each event
        event_pat : voxel by event ndarray
            mean event patterns to compute variance around
        Returns
        -------
        ev_var : ndarray of variances for each event
        """
        Dz = stats.zscore(D, axis=1, ddof=1)
        ev_var = np.empty(event_pat.shape[1])
        for e in range(event_pat.shape[1]):
            # Only compute variances for weights > 0.1% of max weight
            nz = weights[:, e] > np.max(weights[:, e])/1000
            sumsq = np.dot(weights[nz, e],
                           np.sum(np.square(Dz[nz, :] -
                                  event_pat[:, e]), axis=1))
            ev_var[e] = sumsq/(np.sum(weights[nz, e]) -
                               np.sum(np.square(weights[nz, e])) /
                               np.sum(weights[nz, e]))
        ev_var = ev_var / D.shape[1]
        return ev_var

    def model_prior(self, t):
        """Returns the prior probability of the HMM
        Runs forward-backward without any data, showing the prior distribution
        of the model (for comparison with a posterior).
        Parameters
        ----------
        t: int
            Number of timepoints
        Returns
        -------
        segments : time by event ndarray
            segments[t,e] = prior probability that timepoint t is in event e
        test_ll : float
            Log-likelihood of model (data-independent term)"""

        lg, test_ll = self._forward_backward(np.zeros((t, self.n_events)))
        segments = np.exp(lg)

        return segments, test_ll