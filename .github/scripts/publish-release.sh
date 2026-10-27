#!/usr/bin/env bash
set -euo pipefail
cd "$1"
tag=${DESKFLOW_RELEASE_TAG:?Missing release tag}
sha=$(git rev-parse HEAD)
# Listing first distinguishes an absent release from authentication/network errors.
release_id=$(gh api --paginate "repos/$GH_REPO/releases" \
  --jq ".[] | select(.tag_name == \"$tag\") | .id")
if [[ "$tag" == continuous ]]; then
  refs=$(gh api "repos/$GH_REPO/git/matching-refs/tags/continuous" --jq '.[].ref')
  if grep -qx 'refs/tags/continuous' <<< "$refs"; then
    gh api --method PATCH "repos/$GH_REPO/git/refs/tags/continuous" -f sha="$sha" -F force=true
  else
    gh api --method POST "repos/$GH_REPO/git/refs" -f ref=refs/tags/continuous -f sha="$sha"
  fi
else
  test "$(git rev-list -n 1 "$tag")" = "$sha"
fi
flags=(--title "Deskflow $DESKFLOW_PACKAGE_VERSION" --notes-file release-notes.md)
if [[ "$DESKFLOW_PRERELEASE" == true ]]; then
  flags+=(--prerelease --latest=false)
else
  flags+=(--prerelease=false --latest)
fi
if [[ -z "$release_id" ]]; then
  # Stage all assets in a draft so the first published release is complete.
  gh release create "$tag" --verify-tag --draft "${flags[@]}"
fi
gh release upload "$tag" deskflow-* SHA256SUMS --clobber
gh release edit "$tag" "${flags[@]}" --draft=false
