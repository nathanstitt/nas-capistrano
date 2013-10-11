require "nas/capistrano/version"

module NAS

    module Capistrano

        def last_release_time
            @last_release_time ||= capture( "ls -l --full-time #{releases_path} | awk '{print $6, $7}'|tail -1" )
        end

        def dry_run?
            fetch(:sshkit_backend) == SSHKit::Backend::Printer
        end

        def run_locally(cmd)
            if dry_run?
                info "executing locally: #{cmd.inspect}"
                return ''
            end
            output_on_stdout = `#{cmd}`
            if $?.to_i > 0 # $? is command exit code (posix style)
                fail "Command #{cmd} returned status code #{$?}\n#{output_on_stdout}"
            end
            output_on_stdout
        end

        def change_count_for_paths( *paths )
            capture( "cd #{repo_path} && git shortlog -s --after='#{last_release_time}' -- #{paths.join(' ')}| awk '{ sum+=$1} END {print sum}'" ).to_i
        end

    end

end

include NAS::Capistrano
