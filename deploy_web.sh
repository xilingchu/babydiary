#!/bin/bash
set -e
flutter build web --no-tree-shake-icons
rm -rf .vercel/output/static
mkdir -p .vercel/output/static
cp -r build/web/. .vercel/output/static/
NODE_USE_ENV_PROXY=1 vercel deploy --prebuilt --prod
cp -r build/web/. /home/xlc/.local/share/baby_diary_pb/pb_public/
