# P4 — Auditez un environnement de données

## Présentation du projet

Ce projet a été réalisé dans le cadre du parcours **Data Engineer** d’OpenClassrooms.

L’objectif est d’auditer un environnement de données analytique afin d’identifier des incohérences entre les données de vente, les logs de base de données, les tables métier et les résultats affichés dans un environnement OLAP.

Le projet se place dans le contexte de **SuperSmartMarket**, une chaîne de supermarchés française utilisant une architecture décisionnelle basée sur une base de données opérationnelle, un cube OLAP, Azure Analysis Services et Power BI.

La mission consiste à comprendre l’architecture existante, créer un dictionnaire des données, concevoir un schéma relationnel, construire un prototype local de base de données, vérifier les chiffres d’affaires avec des requêtes SQL, analyser les logs, identifier les causes des incohérences et proposer des mesures correctives pour améliorer la résilience du système de données.

---

## Contexte métier

SuperSmartMarket souhaite renforcer la qualité de ses données afin de fiabiliser ses analyses de chiffre d’affaires et ses rapports décisionnels.

L’entreprise observe un problème important : les chiffres d’affaires historiques ne sont pas stables dans le temps. Par exemple, le chiffre d’affaires du **14 août** était initialement affiché à **275 186,59 €**, puis apparaissait ensuite à **284 243,88 €** dans Power BI.

Ce changement inattendu remet en question la fiabilité du flux de données entre la base opérationnelle, le cube OLAP et les outils de reporting.

Le besoin métier peut être résumé ainsi :

> Auditer l’environnement de données, comprendre l’origine des écarts, confirmer les bons chiffres de vente et proposer des mesures pour renforcer la fiabilité et la résilience de la base de données.

---

## Organisation de la mission

Le projet est structuré en trois parties.

### Partie 1 — Audit de l’architecture et des données

La première partie consiste à comprendre l’architecture de l’entreprise et les données extraites du système OLAP.

Les objectifs sont :

* comprendre les flux de données de l’entreprise ;
* analyser le fichier à plat issu du système OLAP ;
* préparer un dictionnaire des données ;
* créer un schéma relationnel ;
* construire un prototype local de base de données ;
* charger les données ;
* exécuter des requêtes SQL pour vérifier les chiffres de vente.

### Partie 2 — Analyse des logs

La deuxième partie consiste à intégrer et analyser les logs de la base de données.

Les objectifs sont :

* créer une table de logs dans la base de données ;
* insérer les données de logs ;
* vérifier les types et la qualité des données insérées ;
* analyser les actions `INSERT`, `UPDATE` et `DELETE` ;
* croiser les logs avec les tables existantes ;
* identifier les incohérences entre les logs et les tables métier.

### Partie 3 — Recommandations et résilience

La troisième partie consiste à formaliser les résultats de l’audit et à proposer des mesures correctives.

Les objectifs sont :

* rédiger un rapport d’audit ;
* compléter le support de présentation ;
* expliquer le cheminement suivi pour identifier le problème ;
* présenter les résultats ;
* proposer des mesures correctives ;
* intégrer des mesures de résilience dans le prototype ;
* présenter les impacts possibles sur l’environnement OLAP.

---

## Architecture de l’environnement audité

L’environnement étudié repose sur une architecture décisionnelle utilisée pour le reporting et la Business Intelligence.

Le flux global est le suivant :

1. Une base de données en ligne, basée sur Microsoft SQL Server, alimente le système opérationnel.
2. Les données sont utilisées par le site internet et l’ERP de l’entreprise.
3. Les données alimentent un cube OLAP via Microsoft Azure Analysis Services.
4. Les résultats sont exploités dans Power BI pour la visualisation et le reporting.

Le schéma d’architecture est disponible dans le dossier :

```text
diagrams/
```

---

## Modèle de données

Le modèle de données étudié suit une logique de **schéma en étoile**, adaptée à un environnement OLAP.

La table de faits principale est :

| Table           | Rôle                                         |
| --------------- | -------------------------------------------- |
| `sales_details` | Table de faits contenant les lignes de vente |

Les tables de dimensions principales sont :

| Table      | Rôle                                        |
| ---------- | ------------------------------------------- |
| `products` | Informations sur les produits               |
| `clients`  | Informations sur les clients                |
| `employee` | Informations sur les employés               |
| `calendar` | Dimension temporelle liée aux dates d’achat |

Une table de logs est également utilisée pour analyser les actions enregistrées dans le système :

| Table  | Rôle                                                  |
| ------ | ----------------------------------------------------- |
| `logs` | Historique des actions `INSERT`, `UPDATE` et `DELETE` |

Le schéma relationnel est disponible dans le dossier :

```text
diagrams/
```

---

## Dictionnaire des données

Un dictionnaire des données a été réalisé afin de documenter les principales tables, leurs colonnes, leurs types de données, les clés primaires, les clés étrangères et les descriptions métier.

Le dictionnaire couvre notamment :

* la table `sales_details` ;
* la table `products` ;
* la table `clients` ;
* la table `calendar` ;
* la table `employee`.

Le dictionnaire des données est disponible dans le dossier :

```text
data_dictionary/
```

---

## Prototype de base de données

Un prototype local de base de données a été construit afin de valider les chiffres de vente et de faciliter l’analyse des logs.

Ce prototype permet de :

* charger les données extraites du système OLAP ;
* structurer les données selon un schéma relationnel ;
* exécuter des requêtes SQL de validation ;
* comparer les résultats avec les chiffres affichés dans Power BI ;
* intégrer les logs dans une table dédiée ;
* analyser les actions `INSERT`, `UPDATE` et `DELETE` ;
* proposer des mécanismes de monitoring et de correction.

Le prototype a été utilisé comme support d’analyse et de validation dans le cadre de l’audit.

---

## Requêtes SQL et analyses réalisées

Les requêtes SQL ont permis de répondre aux besoins métier suivants :

1. confirmer le chiffre d’affaires total du 14 août ;
2. calculer le chiffre d’affaires par client pour le top 10 des clients ;
3. calculer la part de chiffre d’affaires encaissée par employé ;
4. analyser les logs d’insertion, de mise à jour et de suppression ;
5. vérifier la cohérence entre les logs et les tables de dimensions ;
6. identifier les enregistrements manquants ;
7. identifier les valeurs incorrectes dans les logs ;
8. proposer des views de monitoring pour suivre les anomalies ;
9. proposer des corrections contrôlées pour certains écarts ;
10. proposer des mesures de résilience comme des contraintes, triggers et contrôles SQL.

Les requêtes SQL nettoyées sont disponibles dans le dossier :

```text
sql/
```

Le fichier principal est :

```text
sql/audit_queries.sql
```

---

## Problèmes identifiés

L’audit a permis d’identifier plusieurs problèmes importants.

### 1. Écart dans les chiffres de vente

Un écart a été observé dans le chiffre d’affaires du 14 août :

* valeur initialement signalée : **275 186,59 €** ;
* valeur confirmée après vérification : **284 243,88 €**.

L’analyse a permis de confirmer que le chiffre correct était **284 243,88 €**.

### 2. Valeurs invalides dans les logs produits

Des anomalies ont été détectées dans les logs liés aux mises à jour des produits.

Certaines valeurs censées représenter des prix contenaient des dates au lieu de valeurs numériques.

L’audit a identifié **136 entrées invalides** dans les logs.

### 3. Clients manquants

Les logs indiquaient des actions d’insertion pour certains clients, mais ces clients n’étaient pas présents dans la table `clients`.

L’audit a identifié **20 clients manquants**.

### 4. Incohérences dans les mots de passe employés

Des mises à jour de `hash_mdp` étaient présentes dans les logs, mais les valeurs ne correspondaient pas aux données de la table `employee`.

L’audit a identifié **7 incohérences** liées aux mises à jour des mots de passe.

### 5. Suppressions d’employés

L’analyse des logs `DELETE` sur la table `employee` a confirmé que les enregistrements correspondants avaient bien été supprimés de la table des employés.

---

## Recommandations proposées

Plusieurs recommandations ont été proposées pour améliorer la qualité et la résilience de l’environnement de données.

### Mise en place de views de monitoring

Des views SQL peuvent être utilisées pour détecter dynamiquement les anomalies, par exemple :

* clients présents dans les logs mais absents de la table `clients` ;
* incohérences entre les logs et la table `employee` ;
* valeurs invalides dans les logs liés aux produits.

### Collaboration avec l’équipe OLTP

Certaines anomalies semblent provenir du système transactionnel ou du processus de génération des logs.

Une collaboration avec l’équipe OLTP est recommandée afin d’identifier les causes profondes et d’éviter que les mêmes erreurs ne se reproduisent.

### Automatisation des alertes

Des alertes automatiques peuvent être ajoutées afin de notifier les équipes lorsqu’une anomalie critique est détectée.

Ces alertes pourraient être envoyées par email, Slack ou un autre outil de monitoring.

### Renforcement des contrôles en amont

Pour éviter les erreurs à la source, il est recommandé d’ajouter :

* des contraintes SQL ;
* des validations de type de données ;
* des triggers ;
* des procédures stockées ;
* des règles de contrôle avant intégration dans l’environnement analytique.

---

## Livrables du projet

Les livrables principaux du projet sont :

| Livrable                 | Description                                                                                                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rapport d’audit          | Rapport PDF présentant les constats, l’analyse des écarts et les recommandations                                                                                              |
| Support de présentation  | Présentation PPT contenant l’architecture, le dictionnaire des données, le schéma relationnel, les résultats SQL, l’analyse des logs, les mesures correctives et le prototype |
| Dictionnaire des données | Fichier documentant les tables et colonnes principales                                                                                                                        |
| Schémas                  | Architecture de l’entreprise et schéma relationnel du prototype                                                                                                               |
| Requêtes SQL             | Requêtes SQL nettoyées pour la validation du chiffre d’affaires, l’analyse des logs, les views de monitoring et les mesures correctives proposées                             |

---

## Résultats obtenus

Le projet a permis de produire :

* un rapport d’audit structuré ;
* une présentation complète des analyses ;
* un dictionnaire des données ;
* un schéma relationnel du modèle OLAP ;
* une validation du chiffre d’affaires correct du 14 août ;
* une analyse des logs `INSERT`, `UPDATE` et `DELETE` ;
* l’identification de clients manquants ;
* l’identification de valeurs invalides dans les logs produits ;
* l’identification d’incohérences dans les mots de passe employés ;
* des requêtes SQL documentées ;
* des views de monitoring proposées ;
* des pistes d’automatisation et de prévention des anomalies.

---

## Technologies et concepts utilisés

* SQL
* MySQL
* Analyse de logs
* Audit de base de données
* Modèle OLAP
* Schéma en étoile
* Tables de faits et tables de dimensions
* Data quality
* Business Intelligence
* Power BI
* Azure Analysis Services
* Monitoring
* Views SQL
* Triggers
* Contraintes SQL
* Procédures stockées
* Contrôles de cohérence
* Excel
* PowerPoint

---

## Structure du dépôt

```text
.
├── README.md
├── audit_report/
│   └── MotasemAbualqumboz_Rapport_Audit.pdf
├── presentation/
│   └── MotasemAbualqumboz_Presentation_Audit.pptx
├── data_dictionary/
│   └── Data_Dictionary_OLAP_Multi_Sheet.xlsx
├── diagrams/
│   ├── Schema_architecture.jpg
│   └── ERD_OLAP_star_schema.png
└── sql/
    └── audit_queries.sql
```

---

## Données sources

Les fichiers de données brutes ne sont pas inclus dans ce dépôt public afin de garder le repository léger et d’éviter de publier des données opérationnelles ou sensibles.

Le dépôt contient les livrables principaux du projet : rapport d’audit, présentation, dictionnaire des données, schémas et requêtes SQL nettoyées.

---

## Compétences démontrées

Ce projet démontre les compétences suivantes :

* compréhension d’un environnement analytique OLAP ;
* analyse d’un schéma en étoile ;
* création d’un dictionnaire des données ;
* création d’un schéma relationnel ;
* construction d’un prototype local de base de données ;
* chargement de données dans une base SQL ;
* validation de chiffres de vente par requêtes SQL ;
* analyse de logs de base de données ;
* identification d’écarts entre logs et tables métier ;
* création de requêtes SQL d’audit ;
* proposition de views de monitoring ;
* formulation de recommandations techniques ;
* proposition de mécanismes de résilience ;
* communication des résultats sous forme de rapport et de présentation.

---

## Valeur ajoutée du projet

Ce projet montre la capacité à auditer un environnement de données existant, à identifier des incohérences critiques et à proposer des actions concrètes pour améliorer la fiabilité du système.

Dans un contexte professionnel, ce type d’audit permet de renforcer la confiance dans les rapports décisionnels, d’améliorer la qualité des données et de réduire les risques liés à des décisions basées sur des informations incorrectes.

---

## Limites et améliorations possibles

Ce projet constitue un audit académique sur un périmètre défini.

Plusieurs améliorations pourraient être envisagées dans une version plus avancée :

* automatisation complète des contrôles de qualité ;
* mise en place d’alertes temps réel ;
* intégration d’un tableau de bord de monitoring ;
* mise en place de tests de non-régression sur les données ;
* documentation plus détaillée du pipeline OLTP vers OLAP ;
* nettoyage et publication d’un notebook sans identifiants ni données sensibles ;
* industrialisation des views, triggers et contraintes dans un environnement contrôlé.

---

## Auteur

**Motasem Abualqumboz**

Parcours Data Engineer — OpenClassrooms
