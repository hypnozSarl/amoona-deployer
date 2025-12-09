## Description

<!-- Describe your changes in detail -->

## Type of Change

<!-- Put an `x` in all boxes that apply -->

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure change (Kubernetes manifests, Kustomize configs)

## Checklist

<!-- Put an `x` in all boxes that apply -->

- [ ] I have tested my changes locally
- [ ] I have run `kubectl kustomize k8s/overlays/dev` to validate manifests
- [ ] I have updated the documentation accordingly
- [ ] My changes follow the project's coding style
- [ ] I have added appropriate labels to this PR

## Testing

<!-- Describe the tests you ran and how to reproduce them -->

```bash
# Commands to test this PR
kubectl kustomize k8s/overlays/dev
./scripts/deploy-all.sh dev --dry-run
```

## Screenshots (if applicable)

<!-- Add screenshots to help explain your changes -->

## Additional Notes

<!-- Any additional information that reviewers should know -->
