#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project_file="$repo_root/Mosaic.xcodeproj/project.pbxproj"

/usr/bin/ruby - "$project_file" <<'RUBY'
path = ARGV.fetch(0)
contents = File.read(path)
pattern = /^(\s*)SystemCapabilities = ".*";$/
matches = contents.scan(pattern)
abort "Expected one XcodeGen-serialized SystemCapabilities entry; found #{matches.count}." unless matches.count == 1

indent = matches.first.first
replacement = <<~PBX.chomp.lines.map { |line| indent + line }.join
SystemCapabilities = {
	com.apple.InAppPurchase = {
		enabled = 1;
	};
	com.apple.SignInWithApple = {
		enabled = 1;
	};
};
PBX

File.write(path, contents.sub(pattern, replacement))
RUBY
