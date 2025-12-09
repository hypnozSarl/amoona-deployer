# Contributing to Amoona Deployer

Merci de votre interet pour contribuer a ce projet!

## Comment Contribuer

### Reporter un Bug

1. Verifiez que le bug n'a pas deja ete reporte dans les [Issues](../../issues)
2. Ouvrez une nouvelle issue avec:
   - Description claire du probleme
   - Etapes pour reproduire
   - Comportement attendu vs observe
   - Environnement (K8s version, OS, etc.)

### Proposer une Amelioration

1. Ouvrez une issue pour discuter de votre idee
2. Attendez la validation avant de commencer le developpement
3. Suivez le processus de Pull Request ci-dessous

### Pull Request

1. Fork le repository
2. Creez une branche feature: `git checkout -b feature/ma-fonctionnalite`
3. Committez vos changements: `git commit -m 'feat: ajout de ma fonctionnalite'`
4. Poussez la branche: `git push origin feature/ma-fonctionnalite`
5. Ouvrez une Pull Request

## Standards de Code

### Messages de Commit

Suivez le format [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[body optionnel]

[footer optionnel]
```

Types:
- `feat`: nouvelle fonctionnalite
- `fix`: correction de bug
- `docs`: documentation
- `style`: formatage
- `refactor`: refactoring
- `test`: ajout/modification de tests
- `chore`: maintenance

### YAML/Kubernetes

- Indentation: 2 espaces
- Labels coherents: `app`, `component`, `tier`
- Resources: toujours definir `requests` et `limits`
- Probes: toujours definir `liveness` et `readiness`

### Scripts Shell

- Shebang: `#!/bin/bash`
- Options: `set -euo pipefail`
- Variables: `UPPER_CASE` pour les constantes
- Fonctions: `lower_case` avec underscores

## Structure du Projet

```
.
├── k8s/
│   ├── base/           # Configurations de base
│   └── overlays/       # Surcharges par environnement
├── scripts/            # Scripts d'automatisation
├── examples/           # Exemples d'integration
└── docs/               # Documentation
```

## Tests

Avant de soumettre:

```bash
# Valider les manifestes Kustomize
kubectl kustomize k8s/overlays/dev > /dev/null

# Verifier la syntaxe des scripts
shellcheck scripts/*.sh

# Tester le deploiement (si possible)
./scripts/deploy-all.sh dev --dry-run
```

## Documentation

- Mettre a jour le README si necessaire
- Documenter les nouvelles fonctionnalites
- Ajouter des exemples si pertinent

## Questions?

Ouvrez une [Discussion](../../discussions) pour toute question.
