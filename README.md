# VisionCraft AI — Générateur de labels d’images avec AWS Rekognition

VisionCraft AI est une application web qui permet d’envoyer une image JPEG, de la faire analyser par **Amazon Rekognition**, puis d’afficher une copie annotée avec les objets détectés, leurs scores de confiance et leurs cadres de délimitation rouges.

## Fonctionnement

1. L’utilisateur sélectionne une image depuis le site web statique.
2. Le navigateur demande à une Lambda une URL S3 présignée.
3. L’image est envoyée directement dans le bucket S3 d’entrée.
4. Un événement S3 déclenche la Lambda `process-image-add-label`.
5. La Lambda appelle Amazon Rekognition, dessine les cadres et libellés avec Pillow, puis enregistre l’image finale dans le bucket de sortie.
6. Le site interroge la Lambda d’URL présignée jusqu’à ce que l’image traitée soit disponible, puis l’affiche et permet son téléchargement.

<img width="1170" height="1260" alt="visioncraft-architecture drawio (1)" src="https://github.com/user-attachments/assets/5f197bc5-4a5e-4df5-8761-8bcf6b91e791" />


## Technologies

- Amazon S3 : hébergement statique, stockage des images source et traitées
- AWS Lambda (Python / boto3) : génération d’URL présignées et traitement des images
- Amazon Rekognition : détection des labels et des instances
- Pillow : dessin des cadres et des textes sur l’image
- HTML, CSS et JavaScript : interface web
- AWS CloudFormation : modèle d’infrastructure de départ

## Contenu du dépôt

| Élément | Rôle |
| --- | --- |
| `index.html` | Interface VisionCraft AI à héberger dans le bucket web. |
| `fichier projet/process-image-add-label.txt` | Code de la Lambda appelée lors d’un dépôt dans S3. |
| `fichier projet/GetPresignedURL.txt` | Code de la Lambda qui génère les URL d’envoi et de consultation. |
| `Cloudformation file/infrastructure vision craft.txt` | Modèle CloudFormation de l’infrastructure. |
| `description of the action.txt` | Notes de conception et ressources AWS utilisées. |

## Ressources AWS attendues

Le projet utilise trois buckets S3 :

- `front-end-website-label-image` : site web statique.
- `project-label-image-receiver` : images envoyées par les utilisateurs.
- `project-label-image-output` : images annotées générées par la Lambda.

Les noms figurant dans les scripts sont des exemples de déploiement. Adaptez-les à votre compte AWS et à votre région avant de déployer.

## Déploiement

### 1. Préparer la Lambda de traitement

Créez une fonction Lambda Python nommée `process-image-add-label` et copiez le code de `fichier projet/process-image-add-label.txt`.

Cette fonction doit :

- être déclenchée par les événements `ObjectCreated` du bucket d’entrée ;
- disposer d’une couche Lambda contenant Pillow ;
- avoir le droit de lire le bucket d’entrée, d’écrire dans le bucket de sortie et d’appeler `rekognition:DetectLabels`.

### 2. Préparer la Lambda d’URL présignée

Créez une seconde Lambda à partir de `fichier projet/GetPresignedURL.txt`, puis exposez-la avec une Lambda Function URL ou Amazon API Gateway. Renseignez son URL dans `index.html` :

```js
const LAMBDA_URL = 'https://…lambda-url.<region>.on.aws/';
```

### 3. Configurer les buckets et CORS

- Activez l’hébergement de site statique sur le bucket frontend et envoyez-y `index.html`.
- Ajoutez CORS sur le bucket d’entrée pour autoriser `PUT` depuis l’origine du site.
- Ajoutez CORS sur le bucket de sortie pour autoriser `GET` depuis l’origine du site.
- Configurez la notification S3 du bucket d’entrée vers la Lambda de traitement.

Un modèle de base se trouve dans `Cloudformation file/infrastructure vision craft.txt` ; complétez-le avec le code de production, la couche Pillow, les notifications S3 et les autorisations Rekognition.

## Utilisation

1. Ouvrez l’URL du site S3.
2. Cliquez dans la zone d’envoi et sélectionnez une image JPEG.
3. Attendez la progression : envoi, analyse IA, puis résultat.
4. Téléchargez l’image annotée avec le bouton **Download**.

## Points d’attention

- Les URL présignées expirent : 5 minutes pour l’envoi et 60 secondes pour la consultation dans la configuration actuelle.
- Le frontend accepte actuellement les JPEG uniquement ; la Lambda enregistre aussi la sortie au format JPEG.
- Les politiques CORS avec `*` et l’accès public sont pratiques pour une démo, mais doivent être restreints à votre domaine en production.
- Évitez de réutiliser directement le nom de fichier fourni par un utilisateur : ajoutez un identifiant unique afin d’éviter les collisions et les écrasements.
- Ajoutez une durée maximale de polling et un affichage d’erreur dans l’interface pour les échecs de traitement.

## Prérequis

- Un compte AWS avec accès à S3, Lambda, IAM et Amazon Rekognition.
- Une région AWS prise en charge par Rekognition (les scripts utilisent `us-east-1`).
- Python 3.x et une couche Lambda contenant Pillow pour la fonction de traitement.

## Licence

Projet pédagogique. Ajoutez une licence explicite avant toute distribution ou réutilisation publique.
