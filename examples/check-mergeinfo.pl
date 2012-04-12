# Check that merges are performed on allowed places only

my @allowed_merge_roots = (
    qr@^(?:trunk|branches/[^/]+)/$@, # only on trunk and on branches roots
);

# Different versions follow, each one with different
# semantics/performance trade offs. Chose one of them.

# VERSION A: This first version checks every modified path that has a
# svn:mergeinfo property. Each one of them must match at least one of
# the regexes in @allowed_merge_roots. It is, perhaps, too strict,
# because if your repo already has non-allowed subdirectories with
# svn:mergeinfo before you enable the hook, you won't be able to
# perform any other merge, since those subdirectories would have their
# mergeinfo changed too. Besides, having a svn:mergeinfo property
# doesn't mean that the property has been modified in this commit.

PRE_COMMIT {
    my ($svnlook) = @_;
  PATH:
    foreach my $path (
	grep { exists $svnlook->proplist($_)->{'svn:mergeinfo'} }
	sort $svnlook->prop_modified()
    ) {
	foreach my $root (@allowed_merge_roots) {
	    next PATH if $path =~ $root;
	}
	die "Merge not allowed on $path\n";
    }
};

# VERSION B: This second version checks only the smallest modified
# path that has a svn:mergeinfo property. This smallest path is
# considered the merge "root". Hence, it will allow subsequent merges
# (on allowed roots) even if there are some subdirectories that
# already had mergeinfo properties before you enabled the
# hook. However, it also doesn't check if the property has changed.

PRE_COMMIT {
    my ($svnlook) = @_;

    my @mergeds = grep {exists $svnlook->proplist($_)->{'svn:mergeinfo'}} $svnlook->prop_modified();
    return unless @mergeds;

    require List::Util;
    my $merge_root = List::Util::minstr @mergeds;

    require List::MoreUtils;
    return if List::MoreUtils::any {$merge_root =~ $_} @allowed_merge_roots;

    die "Merge not allowed on $merge_root\n";
};

# VERSION C: This third version does it completely right. First it
# groks every modified path that has the svn:mergeinfo property. Then,
# for each such path in string order, it checks if its svn:mergeinfo
# property has changed in the commit. The first such path must be the
# merge root and it must match at least one of the allowed merge roots
# or die otherwise.

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
