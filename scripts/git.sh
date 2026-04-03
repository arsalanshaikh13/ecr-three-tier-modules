git add .; git commit -m "host network specific changes made";
git tag nextjs-host; 
git checkout head^
git tag nextjs-bridge;
git push origin --tags;
git checkout -b nextjs-fargate
git checkout main
git checkout -b service-discovery
git checkout nextjs-fargate