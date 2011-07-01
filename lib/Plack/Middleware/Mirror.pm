# vim: set ts=2 sts=2 sw=2 expandtab smarttab:
#
# This file is part of Plack-Middleware-Mirror
#
# This software is copyright (c) 2011 by Randy Stauner.
#
# This is free software; you can redistribute it and/or modify it under
# the same terms as the Perl 5 programming language system itself.
#
use strict;
use warnings;

package Plack::Middleware::Mirror;
BEGIN {
  $Plack::Middleware::Mirror::VERSION = '0.100';
}
BEGIN {
  $Plack::Middleware::Mirror::AUTHORITY = 'cpan:RWSTAUNER';
}
# ABSTRACT: Save responses to disk to mirror a site

use parent 'Plack::Middleware';
use Plack::Util;
use Plack::Util::Accessor qw(path mirror_dir debug);

use File::Path qw(make_path);;
use File::Basename ();

sub call {
  my ($self, $env) = @_;

  my $matches = $self->path or return;
  $matches = [ $matches ] unless ref $matches eq 'ARRAY';

  # what is the best way to get this value?
  # Plack::Request->new($env)->path;
  my $path_info = $env->{PATH_INFO};

  for my $match (@$matches) {
    return $self->_save_response($env, $path_info)
      if ref($match) eq 'CODE' ? $match->($path_info) : $path_info =~ $match;
  }
  return $self->app->($env);
}

sub _save_response {
  my ($self, $env, $path_info) = @_;
  # TODO: should we use Cwd here?
  my $dir = $self->mirror_dir || 'mirror';

  # TODO: use File::Spec
  my $file = $dir . $path_info;
  # FIXME: do we need to append to $response->[2] manually?
  my $content = '';

  # TODO: use logger?
  print STDERR ref($self) . " mirror: $path_info ($file)\n"
    if $self->debug;

  # fall back to normal request, but intercept response and save it
  return $self->response_cb(
    $self->app->($env),
    sub {
      #my ($response) = @_;
      # content filter
      return sub {
        my ($chunk) = @_;

        # end of content
        if ( !defined $chunk ) {
          # TODO: there must be something more appropriate than dirname()
          my $fdir = File::Basename::dirname($file);
          make_path($fdir) unless -d $fdir;

          # if writing to the file fails, don't kill the request
          local $@;
          eval {
            open(my $fh, '>', $file)
              or die "Failed to open '$file': $!";
            binmode($fh);
            print $fh $content
              or die "Failed to write to '$file': $!";
            # TODO: utime the file with Last-Modified
          };
          warn $@ if $@;
        }
        # if called multiple times, concatenate response
        else {
          $content .= $chunk;
        }
        return $chunk;
      }
    }
  );
}

1;


__END__
=pod

=for :stopwords Randy Stauner TODO cpan testmatrix url annocpan anno bugtracker rt cpants
kwalitee diff irc mailto metadata placeholders

=head1 NAME

Plack::Middleware::Mirror - Save responses to disk to mirror a site

=head1 VERSION

version 0.100

=head1 SYNOPSIS

  # app.psgi
  use Plack::Builder;

  builder {
    # other middleware...

    # save response to disk (beneath $dir) if uri matches
    enable Mirror => path => $match, mirror_dir => $dir;

    # your app...
  };

=head1 DESCRIPTION

  NOTE: This is currently considered alpha quality.
  Only the simplest case has been considered.
  Suggestions, patches, and pull requests are welcome.

This middleware will save the content of the response
in a tree structure reflecting the URI path info
to create a mirror of the site on disk.

This is different than L<Plack::Middleware::Cache>
which saves the entire response (headers and all)
to speed response time on subsequent and lessen external network usage.

In contrast this middleware saves the static file requested
to the disk preserving the file name and directory structure.
This creates a physical mirror of the site so that you can do other
things with the directory structure if you desire.

C<NOTE>: This middleware does not short-circuit the request
(as L<Plack::Middleware::Cache> does), so if there is no other middleware
to stop the request this module will let the request continue and
save the latest version of the response each time.
This is considered a feature.

=for test_synopsis my ($config, $match, $dir);

=head1 TODO

=over 4

=item *

C<utime> the mirrored file using Last-Modified

=item *

Tests

=item *

Use L<File::Spec>, etc to make it more cross-platform

=item *

Determine how this (should) work(s) with non-static resources (query strings)

=back

=head1 SEE ALSO

=over 4

=item *

L<Plack::Middleware::Cache>

=back

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Plack::Middleware::Mirror

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Plack-Middleware-Mirror>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Plack-Middleware-Mirror>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Plack-Middleware-Mirror>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/P/Plack-Middleware-Mirror>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Plack-Middleware-Mirror>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Plack::Middleware::Mirror>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-plack-middleware-mirror at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Plack-Middleware-Mirror>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code


L<http://github.com/magnificent-tears/Plack-Middleware-Mirror>

  git clone http://github.com/magnificent-tears/Plack-Middleware-Mirror

=head1 AUTHOR

Randy Stauner <rwstauner@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Randy Stauner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

