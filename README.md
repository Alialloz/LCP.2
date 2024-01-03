# LCP.2
LCP.2 ("Copie Paresseuse de Fichiers"), est une application avancée de LCP en C pour la copie de fichiers. L'accent est mis sur l'utilisation efficace de la communication inter-processus, avec des processus parent et enfant qui coopèrent pour accomplir des tâches de copie de fichiers en utilisant des tubes simples pour la transmission de données.

## Fonctionnalités Clés

- **Processus Parent et Enfant**: Implémentation d'une architecture où le processus parent lit et le processus enfant écrit les données.
- **Communication via Tubes**: Utilisation de tubes pour échanger des informations essentielles comme la taille du fichier et la somme de contrôle.
- **Copie Optimisée**: La copie des fichiers est effectuée uniquement pour les blocs nécessaires, améliorant ainsi l'efficacité.

## Fonctionnalité Bonus

- **Option `-s` pour Sockets Unix**: Ajout d'une option permettant d'utiliser des sockets Unix pour la communication inter-processus, étendant les capacités du programme.

## Développement et Utilisation

- Le programme est entièrement développé en C.
- Le fichier source principal est `lcp.c`, situé à la racine du projet.
- Le projet est conçu pour être compact et efficace, avec une implémentation concentrée dans un seul fichier source.
- La compilation est gérée à l'aide d'un Makefile fourni.

## Exécution et Tests

- Intégration de tests automatisés accessibles via `make check`.
- Possibilité de mises à jour continues pour améliorer ou étendre les fonctionnalités du programme.

## Points Techniques

- **Copie Paresseuse**: Analyse des fichiers source et destination pour copier uniquement les blocs nécessaires.
- **Gestion des Erreurs**: Affichage de messages d'erreur en cas de problèmes liés aux fichiers ou autres aspects de l'application.
