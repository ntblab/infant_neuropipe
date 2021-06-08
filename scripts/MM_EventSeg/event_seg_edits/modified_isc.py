# Import a bunch of stuff 
from matplotlib import pyplot as plt
import matplotlib.patches as patches
import numpy as np
import pandas as pd
import sys
import os
import scipy.stats as stats
from scipy.stats import norm, zscore, pearsonr, ttest_ind
from scipy.signal import gaussian, convolve
from scipy.spatial.distance import squareform
from sklearn import decomposition, preprocessing
from sklearn.model_selection import LeaveOneOut, RepeatedKFold
import seaborn as sns
import itertools
import nibabel as nib
from nilearn.input_data import NiftiMasker
from nilearn import plotting


# Edited ISC code from BrainIAK 
def isc(data, pairwise=False, tolerate_nans=True):
    
    # Check tolerate_nans input and use either mean/nanmean and exclude voxels
    if tolerate_nans:
        mean = np.nanmean
    else:
        mean = np.mean

    n_subjects = data.shape[2] # last shape
    
    # Compute correlation for only two participants
    if n_subjects == 2:

        # Compute correlation for each corresponding voxel
        iscs_stack, _ = array_correlation(data[:,:, 0],
                                       data[:,:, 1])
        iscs_stack = iscs_stack[np.newaxis, :]

    # Compute pairwise ISCs using voxel loop and corrcoef for speed
    elif pairwise:

        # Swap axes for np.corrcoef
        data = np.swapaxes(data, 2, 0)

        # Loop through voxels
        voxel_iscs = []
        for v in np.arange(data.shape[1]):
            voxel_data = data[:, v, :]

            # Correlation matrix for all pairs of subjects (triangle)
            iscs = squareform(np.corrcoef(voxel_data), checks=False)
            voxel_iscs.append(iscs)

        iscs_stack = np.column_stack(voxel_iscs)

    # Compute leave-one-out ISCs
    elif not pairwise:

        # Loop through left-out subjects
        iscs_stack = []
        for s in np.arange(n_subjects):

            # Correlation between left-out subject and mean of others
            array_corr,intersect_mask=array_correlation(
                    data[:,:, s],
                    mean(np.delete(data, s, axis=2), axis=2))

            iscs_stack.append(array_corr)

    iscs = np.array(iscs_stack)

    # Throw away first dimension if singleton
    if iscs.shape[0] == 1:
        iscs = iscs[0]

    return iscs

def compute_summary_statistic(iscs, summary_statistic='mean', axis=None):

    if summary_statistic not in ('mean', 'median'):
        raise ValueError("Summary statistic must be 'mean' or 'median'")

    # Compute summary statistic
    if summary_statistic == 'mean':
        statistic = np.tanh(np.nanmean(np.arctanh(iscs), axis=axis))
    elif summary_statistic == 'median':
        statistic = np.nanmedian(iscs, axis=axis)

    return statistic

def array_correlation(x, y, axis=0):

    # Accommodate array-like inputs
    if not isinstance(x, np.ndarray):
        x = np.asarray(x)
    if not isinstance(y, np.ndarray):
        y = np.asarray(y)

    # Check that inputs are same shape
    if x.shape != y.shape:
        raise ValueError("Input arrays must be the same shape")

    # Transpose if axis=1 requested (to avoid broadcasting
    # issues introduced by switching axis in mean and sum)
    if axis == 1:
        x, y = x.T, y.T
    
    
    notnans_x=~np.isnan(np.array(x))
    included_trs_x=notnans_x[:,0]
    
    notnans_y=~np.isnan(np.array(y))
    included_trs_y=notnans_y[:,0]
    
    included_trs=included_trs_y*included_trs_x # filter out nans from both the group and individ
    
    x=x[included_trs,:]
    y=y[included_trs,:]
    
    # Center (de-mean) input variables
    x_demean = x - np.mean(x, axis=0)
    y_demean = y - np.mean(y, axis=0)

    # Compute summed product of centered variables
    numerator = np.sum(x_demean * y_demean, axis=0)

    # Compute sum squared error
    denominator = np.sqrt(np.sum(x_demean ** 2, axis=0) *
                          np.sum(y_demean ** 2, axis=0))

    return numerator / denominator, included_trs

def bootstrap_isc(iscs, pairwise=False, summary_statistic='median',
                  n_bootstraps=1000, ci_percentile=95, random_state=None):
    
    prng=np.random.RandomState(random_state)
    n_subjects=len(iscs)
    
    # Check for valid summary statistic
    if summary_statistic not in ('mean', 'median'):
        raise ValueError("Summary statistic must be 'mean' or 'median'")

    # Compute summary statistic for observed ISCs
    observed = compute_summary_statistic(iscs,
                                         summary_statistic=summary_statistic,
                                         axis=0)

    # Set up an empty list to build our bootstrap distribution
    distribution = []

    # Loop through n bootstrap iterations and populate distribution
    for i in np.arange(n_bootstraps):

        # Randomly sample subject IDs with replacement
        subject_sample = sorted(prng.choice(np.arange(n_subjects),
                                            size=n_subjects))

        # Squareform and shuffle rows/columns of pairwise ISC matrix to
        # to retain correlation structure among ISCs, then get triangle
        if pairwise:

            # Loop through voxels
            isc_sample = []
            for voxel_iscs in iscs.T:

                # Square the triangle and fill diagonal
                voxel_iscs = squareform(voxel_iscs)
                np.fill_diagonal(voxel_iscs, 1)

                # Check that pairwise ISC matrix is square and symmetric
                assert voxel_iscs.shape[0] == voxel_iscs.shape[1]
                assert np.allclose(voxel_iscs, voxel_iscs.T)

                # Shuffle square correlation matrix and get triangle
                voxel_sample = voxel_iscs[subject_sample, :][:, subject_sample]
                voxel_sample = squareform(voxel_sample, checks=False)

                # Censor off-diagonal 1s for same-subject pairs
                voxel_sample[voxel_sample == 1.] = np.NaN

                isc_sample.append(voxel_sample)

            isc_sample = np.column_stack(isc_sample)

        # Get simple bootstrap sample if not pairwise
        elif not pairwise:
            isc_sample = iscs[subject_sample, :]

        # Compute summary statistic for bootstrap ISCs per voxel
        # (alternatively could construct distribution for all voxels
        # then compute statistics, but larger memory footprint)
        distribution.append(compute_summary_statistic(
                                isc_sample,
                                summary_statistic=summary_statistic,
                                axis=0))

    # Convert distribution to numpy array
    distribution = np.array(distribution)

    # Compute CIs of median from bootstrap distribution (default: 95%)
    ci = (np.percentile(distribution, (100 - ci_percentile)/2, axis=0),
          np.percentile(distribution, ci_percentile + (100 - ci_percentile)/2,
                        axis=0))

    # Shift bootstrap distribution to 0 for hypothesis test
    shifted = distribution - observed

    # Get p-value for actual median from shifted distribution
    p = p_from_null(observed, shifted,
                    side='two-sided', exact=False,
                    axis=0)

    return observed, ci, p, distribution

def p_from_null(observed, distribution,
                side='two-sided', exact=False,
                axis=None):

    if side not in ('two-sided', 'left', 'right'):
        raise ValueError("The value for 'side' must be either "
                         "'two-sided', 'left', or 'right', got {0}".
                         format(side))

    n_samples = len(distribution)

    if side == 'two-sided':
        # Numerator for two-sided test
        numerator = np.sum(np.abs(distribution) >= np.abs(observed), axis=axis)
    elif side == 'left':
        # Numerator for one-sided test in left tail
        numerator = np.sum(distribution <= observed, axis=axis)
    elif side == 'right':
        # Numerator for one-sided test in right tail
        numerator = np.sum(distribution >= observed, axis=axis)

    # If exact test all possible permutations and do not adjust
    if exact:
        p = numerator / n_samples

    # If not exact test, adjust number of samples to account for
    # observed statistic; prevents p-value from being zero
    else:
        p = (numerator + 1) / (n_samples + 1)

    return p

def permutation_isc(iscs, group_assignment=None, pairwise=False,  # noqa: C901
                    summary_statistic='median', n_permutations=1000,
                    random_state=None):
    
    prng=np.random.RandomState(random_state)
    n_subjects=len(iscs)
    
    # Check for valid summary statistic
    if summary_statistic not in ('mean', 'median'):
        raise ValueError("Summary statistic must be 'mean' or 'median'")

    # Get group parameters
    group_parameters = _get_group_parameters(group_assignment, n_subjects,
 
                                             pairwise=pairwise)

    # Set up permutation type (exact or Monte Carlo)
    if group_parameters['n_groups'] == 1:
        if n_permutations < 2**n_subjects:
            exact_permutations = None
        else:
            exact_permutations = list(product([-1, 1], repeat=n_subjects))
            n_permutations = 2**n_subjects

    # Check for exact test for two groups
    else:
        if n_permutations < np.math.factorial(n_subjects):
            exact_permutations = None
        else:
            
            exact_permutations = list(permutations(
                np.arange(len(group_assignment))))
            n_permutations = np.math.factorial(n_subjects)

    # If one group, just get observed summary statistic
    if group_parameters['n_groups'] == 1:
        observed = compute_summary_statistic(
                        iscs,
                        summary_statistic=summary_statistic,
                        axis=0)[np.newaxis, :]

    # If two groups, get the observed difference
    else:
        observed = (compute_summary_statistic(
                        iscs[group_parameters['group_selector'] ==
                             group_parameters['group_labels'][0], :],
                        summary_statistic=summary_statistic,
                        axis=0) -
                    compute_summary_statistic(
                        iscs[group_parameters['group_selector'] ==
                             group_parameters['group_labels'][1], :],
                        summary_statistic=summary_statistic,
                        axis=0))
        observed = np.array(observed)

    # Set up an empty list to build our permutation distribution
    distribution = []

    # Loop through n permutation iterations and populate distribution
    for i in np.arange(n_permutations):

        # Random seed to be deterministically re-randomized at each iteration
        if exact_permutations:
            prng = None

        # If one group, apply sign-flipping procedure
        if group_parameters['n_groups'] == 1:
            isc_sample = _permute_one_sample_iscs(
                            iscs, group_parameters, i,
                            pairwise=pairwise,
                            summary_statistic=summary_statistic,
                            exact_permutations=exact_permutations,
                            prng=prng)

        # If two groups, set up group matrix get the observed difference
        else:
            isc_sample = _permute_two_sample_iscs(
                            iscs, group_parameters, i,
                            pairwise=pairwise,
                            summary_statistic=summary_statistic,
                            exact_permutations=exact_permutations,
                            prng=prng)

        # Tack our permuted ISCs onto the permutation distribution
        distribution.append(isc_sample)


    # Convert distribution to numpy array
    distribution = np.array(distribution)

    # Get p-value for actual median from shifted distribution
    if exact_permutations:
        p = p_from_null(observed, distribution,
                        side='two-sided', exact=True,
                        axis=0)
    else:
        p = p_from_null(observed, distribution,
                        side='two-sided', exact=False,
                        axis=0)

    return observed, p, distribution


def _get_group_parameters(group_assignment, n_subjects, pairwise=False):

    # Set up dictionary to contain group info
    group_parameters = {'group_assignment': group_assignment,
                        'n_subjects': n_subjects,
                        'group_labels': None, 'groups': None,
                        'sorter': None, 'unsorter': None,
                        'group_matrix': None, 'group_selector': None}

    # Set up group selectors for two-group scenario
    if group_assignment and len(np.unique(group_assignment)) == 2:
        group_parameters['n_groups'] = 2

        # Get group labels and counts
        group_labels = np.unique(group_assignment)
        groups = {group_labels[0]: group_assignment.count(group_labels[0]),
                  group_labels[1]: group_assignment.count(group_labels[1])}

        # For two-sample pairwise approach set up selector from matrix
        if pairwise:
            # Sort the group_assignment variable if it came in shuffled
            # so it's easier to build group assignment matrix
            sorter = np.array(group_assignment).argsort()
            unsorter = np.array(group_assignment).argsort().argsort()

            # Populate a matrix with group assignments
            upper_left = np.full((groups[group_labels[0]],
                                  groups[group_labels[0]]),
                                 group_labels[0])
            upper_right = np.full((groups[group_labels[0]],
                                   groups[group_labels[1]]),
                                  np.nan)
            lower_left = np.full((groups[group_labels[1]],
                                  groups[group_labels[0]]),
                                 np.nan)
            lower_right = np.full((groups[group_labels[1]],
                                   groups[group_labels[1]]),
                                  group_labels[1])
            group_matrix = np.vstack((np.hstack((upper_left, upper_right)),
                                      np.hstack((lower_left, lower_right))))
            np.fill_diagonal(group_matrix, np.nan)
            group_parameters['group_matrix'] = group_matrix

            # Unsort matrix and squareform to create selector
            group_parameters['group_selector'] = squareform(
                                        group_matrix[unsorter, :][:, unsorter],
                                        checks=False)
            group_parameters['sorter'] = sorter
            group_parameters['unsorter'] = unsorter

        # If leave-one-out approach, just user group assignment as selector
        else:
            group_parameters['group_selector'] = group_assignment

        # Save these parameters for later
        group_parameters['groups'] = groups
        group_parameters['group_labels'] = group_labels

    # Manage one-sample and incorrect group assignments
    elif not group_assignment or len(np.unique(group_assignment)) == 1:
        group_parameters['n_groups'] = 1

        # If pairwise initialize matrix of ones for sign-flipping
        if pairwise:
            group_parameters['group_matrix'] = np.ones((
                                            group_parameters['n_subjects'],
                                            group_parameters['n_subjects']))

    elif len(np.unique(group_assignment)) > 2:
        raise ValueError("This test is not valid for more than "
                         "2 groups! (got {0})".format(
                                len(np.unique(group_assignment))))
    else:
        raise ValueError("Invalid group assignments!")

    return group_parameters

def _permute_one_sample_iscs(iscs, group_parameters, i, pairwise=False,
                             summary_statistic='median', group_matrix=None,
                             exact_permutations=None, prng=None):

    # Randomized sign-flips
    if exact_permutations:
        sign_flipper = np.array(exact_permutations[i])
    else:
        sign_flipper = prng.choice([-1, 1],
                                   size=group_parameters['n_subjects'],
                                   replace=True)

    # If pairwise, apply sign-flips by rows and columns
    if pairwise:
        matrix_flipped = (group_parameters['group_matrix'] * sign_flipper
                                                           * sign_flipper[
                                                                :, np.newaxis])
        sign_flipper = squareform(matrix_flipped, checks=False)

    # Apply flips along ISC axis (same across voxels)
    isc_flipped = iscs * sign_flipper[:, np.newaxis]

    # Get summary statistics on sign-flipped ISCs
    isc_sample = compute_summary_statistic(
                    isc_flipped,
                    summary_statistic=summary_statistic,
                    axis=0)

    return isc_sample

def _permute_two_sample_iscs(iscs, group_parameters, i, pairwise=False,
                             summary_statistic='median',
                             exact_permutations=None, prng=None):

    # Shuffle the group assignments
    if exact_permutations:
        group_shuffler = np.array(exact_permutations[i])
    elif not exact_permutations and pairwise:
        group_shuffler = prng.permutation(np.arange(
            len(np.array(group_parameters['group_assignment'])[
                            group_parameters['sorter']])))
    elif not exact_permutations and not pairwise:
        group_shuffler = prng.permutation(np.arange(
            len(group_parameters['group_assignment'])))

    # If pairwise approach, convert group assignments to matrix
    if pairwise:

        # Apply shuffler to group matrix rows/columns
        group_shuffled = group_parameters['group_matrix'][
                            group_shuffler, :][:, group_shuffler]

        # Unsort shuffled matrix and squareform to create selector
        group_selector = squareform(group_shuffled[
                                    group_parameters['unsorter'], :]
                                    [:, group_parameters['unsorter']],
                                    checks=False)

    # Shuffle group assignments in leave-one-out two sample test
    elif not pairwise:

        # Apply shuffler to group matrix rows/columns
        group_selector = np.array(
                    group_parameters['group_assignment'])[group_shuffler]

    # Get difference of within-group summary statistics
    # with group permutation
    isc_sample = (compute_summary_statistic(
                    iscs[group_selector == group_parameters[
                                            'group_labels'][0], :],
                    summary_statistic=summary_statistic,
                    axis=0) -
                  compute_summary_statistic(
                    iscs[group_selector == group_parameters[
                                            'group_labels'][1], :],
                    summary_statistic=summary_statistic,
                    axis=0))

    return isc_sample