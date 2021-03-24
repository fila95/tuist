# frozen_string_literal: true
require "tmpdir"
require "down"
require "open3"
require "macho"

module Fourier
  module Services
    module Update
      class Swiftdoc < Base
        VERSION = "1.0.0-beta.5"
        SOURCE_TAR_URL = "https://github.com/SwiftDocOrg/swift-doc/archive/refs/tags/#{VERSION}.zip"

        def call
          output_directory = File.join(Constants::TUIST_VENDOR_DIRECTORY)

          Dir.mktmpdir do |temporary_dir|
            Dir.mktmpdir do |temporary_output_directory|
              sources_zip_path = download(temporary_dir: temporary_dir)
              sources_path = extract(sources_zip_path)
              build(sources_path, into: temporary_output_directory)

              # # swift-doc expects the lib_InternalSwiftSyntaxParser dynamic library.
              # https://github.com/SwiftDocOrg/homebrew-formulae/blob/master/Formula/swift-doc.rb#L43
              macho = MachO::FatFile.new(File.join(temporary_output_directory, "swift-doc"))
              toolchain = macho.rpaths.find { |path| path.include?(".xctoolchain") }
              syntax_parser_dylib = File.join(toolchain, "lib_InternalSwiftSyntaxParser.dylib")
              FileUtils.copy_entry(syntax_parser_dylib,
                File.join(temporary_output_directory, File.basename(syntax_parser_dylib)))

              FileUtils.rm_rf(output_directory) if Dir.exist?(output_directory)
              FileUtils.copy_entry(temporary_output_directory, output_directory)
              puts(::CLI::UI.fmt("{{success:swiftdoc built and vendored successfully.}}"))
            end
          end
        end

        private

        def download(temporary_dir:)
          puts(::CLI::UI.fmt("Downloading source code from {{info:#{SOURCE_TAR_URL}}}"))
          sources_zip_path = File.join(temporary_dir, "swiftdoc.zip")

          ::CLI::UI::Progress.progress do |bar|
            file_size = 0
            Down.download(
              SOURCE_TAR_URL,
              destination: sources_zip_path,
              content_length_proc: ->(total_size) { file_size = total_size.to_i },
              progress_proc: ->(size) {
                break if file_size == 0
                bar.tick(set_percent: size.to_i / file_size)
              }
            )
          end

          sources_zip_path
        end

        def extract(sources_zip_path)
          puts("Extracting source code...")
          zip_content_path = File.join(File.dirname(sources_zip_path), "content")
          Utilities::Zip.extract(zip: sources_zip_path, into: zip_content_path)
          Dir.glob(File.join(zip_content_path, "*/")).first
        end

        def build(sources_path, into:)
          puts("Building...")

          command = [
            "swift", "build",
            "--configuration", "release",
            "--disable-sandbox",
            "--package-path", sources_path
          ]

          arm_64 = command.dup
          arm_64 += ["--triple", "arm64-apple-macosx"]
          Utilities::System.system(*arm_64)

          x86 = command.dup
          x86 += ["--triple", "x86_64-apple-macosx"]
          Utilities::System.system(*x86)

          Utilities::System.system(
            "lipo", "-create", "-output", File.join(into, "swift-doc"),
            File.join(sources_path, ".build/arm64-apple-macosx/release/swift-doc"),
            File.join(sources_path, ".build/x86_64-apple-macosx/release/swift-doc")
          )

          FileUtils.copy_entry(
            File.join(sources_path, ".build/arm64-apple-macosx/release/swift-doc_swift-doc.bundle"),
            File.join(into, "swift-doc_swift-doc.bundle")
          )
        end
      end
    end
  end
end
