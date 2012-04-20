# The SVNBOOK's section called "The Final Word on Merge Tracking"
# (http://svnbook.red-bean.com/en/1.7/svn.branchmerge.advanced.html#svn.branchmerge.advanced.finalword)
# says that one of Subversion's best practices is to "avoid subtree
# merges and subtree mergeinfo, perform merges only on the root of
# your branches, not on subdirectories or files".

# What follows is a pre-commit hook that checks when it's commiting
# the result of a merge and that the merge root matches on of a list
# of allowed regexes.

my @allowed_merge_roots = (
    qr@^(?:trunk|branches/[^/]+)/$@, # only on trunk and on branches roots
);

# This hook first groks every modified path that has the svn:mergeinfo
# property. Then, for each such path in string order, it checks if its
# svn:mergeinfo property has changed in the commit. The first such
# path must be the merge root and it must match at least one of the
# allowed merge roots or die otherwise.

PRE_COMMIT {
    my ($svnlook) = @_;
    my @mergeds = grep {exists $svnlook->proplist($_)->{'svn:mergeinfo'}} $svnlook->prop_modified();
    return unless @mergeds;

    # Get a SVN::Look to the HEAD revision in order to see what has
    # changed in this commit transaction
    my $headlook = SVN::Look->new($svnlook->repo());

    foreach my $path (sort @mergeds) {
	# Try to get properties for the file in HEAD
	my $head_props = eval { $headlook->proplist($path) };

	# Check if it didn't exist, didn't have the svn:mergeinfo
	# property or if the property was different then.
	if (! $head_props ||
	    ! exists $head_props->{'svn:mergeinfo'} ||
	    $head_props->{'svn:mergeinfo'} ne $svnlook->proplist($path)->{'svn:mergeinfo'}
	) {
	    # We've found a path that had the svn:mergeinfo property
	    # modified in this commit. Since we're looking at them in
	    # string order, the first one found must be the merge
	    # root. Check if it matches any of the allowed roots and
	    # die otherwise.
	    foreach my $allowed_root (@allowed_merge_roots) {
		return if $path =~ $allowed_root;
	    }
	    die "Merge not allowed on '$path'\n";
	}
    }
};

1;
