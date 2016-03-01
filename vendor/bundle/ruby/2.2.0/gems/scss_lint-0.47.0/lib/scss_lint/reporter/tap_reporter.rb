module SCSSLint
  # Reports in TAP format.
  # http://testanything.org/
  class Reporter::TAPReporter < Reporter
    TAP_VERSION = 'TAP version 13'.freeze

    def report_lints
      output = [TAP_VERSION, format_plan(files, lints)]
      return format_output(output) unless files.any?

      output.concat(format_files(files, lints))
      format_output(output)
    end

  private

    # @param files [Array<String>]
    # @param lints [Array<SCSSLint::Lint>]
    # @return [String]
    def format_plan(files, lints)
      files_with_lints = lints.map(&:filename).uniq
      extra_lines = lints.count - files_with_lints.count
      comment = files.count == 0 ? ' # No files to lint' : ''
      "1..#{files.count + extra_lines}#{comment}"
    end

    # @param files [Array<String>]
    # @param lints [Array<SCSSLint::Lint>]
    # @return [Array<String>] one item per ok file or not ok lint
    def format_files(files, lints)
      unless lints.any?
        # There are no lints, so we can take a shortcut and just output an ok
        # test line for every file.
        return files.map.with_index do |filename, index|
          format_ok(filename, index + 1)
        end
      end

      # There are lints, so we need to go through each file, find the lints
      # for the file, and add them to the output.

      # Since we'll be looking up lints by filename for each filename, we want
      # to make a first pass to group all of the lints by filename to make
      # lookup fast.
      grouped_lints = group_lints_by_filename(lints)

      test_number = 1
      files.map do |filename|
        if grouped_lints.key?(filename)
          # This file has lints, so we want to generate a "not ok" test line for
          # each failing lint.
          grouped_lints[filename].map do |lint|
            formatted = format_not_ok(lint, test_number)
            test_number += 1
            formatted
          end
        else
          formatted = format_ok(filename, test_number)
          test_number += 1
          [formatted]
        end
      end.flatten
    end

    # @param lints [Array<SCSSLint::Lint>]
    # @return [Hash] keyed by filename, values are arrays of lints
    def group_lints_by_filename(lints)
      grouped_lints = {}
      lints.each do |lint|
        grouped_lints[lint.filename] ||= []
        grouped_lints[lint.filename] << lint
      end
      grouped_lints
    end

    # @param filename [String]
    # @param test_number [Number]
    # @return [String]
    def format_ok(filename, test_number)
      "ok #{test_number} - #{filename}"
    end

    # @param lint [SCSSLint::Lint]
    # @param test_number [Number]
    # @return [String]
    def format_not_ok(lint, test_number)
      location = lint.location
      test_line_description = "#{lint.filename}:#{location.line}:#{location.column}"
      test_line_description += " #{lint.linter.name}" if lint.linter

      <<-EOS.strip
not ok #{test_number} - #{test_line_description}
  ---
  message: #{lint.description}
  severity: #{lint.severity}
  data:
    file: #{lint.filename}
    line: #{lint.location.line}
    column: #{lint.location.column}
  ...
      EOS
    end

    # @param output [Array<String>]
    # @return [String]
    def format_output(output)
      output.join("\n") + "\n"
    end

    def location(lint)
      "#{log.cyan(lint.filename)}:#{log.magenta(lint.location.line.to_s)}"
    end

    def type(lint)
      lint.error? ? log.red('[E]') : log.yellow('[W]')
    end

    def message(lint)
      linter_name = log.green("#{lint.linter.name}: ") if lint.linter
      "#{linter_name}#{lint.description}"
    end
  end
end
