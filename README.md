# Nas::Capistrano

This is a small collection of capistrano recipes I've put together to
make deploying to my servers a bit easier

I have no intention of submitting to ruby-gems, but feel free to pick
and choose. It's not a turnkey solution by any means.  I doubt it'll
be much use to others as-is.


## Installation

Add this line to your application's Gemfile:

    gem 'nas-capistrano', :git=>https://github.com/nathanstitt/nas-capistrano.git

And then incorporate it into your deploy.rb as normal

    require 'nas/capistrano/extjs'
