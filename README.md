# VisionCraft AI

Application web de détection d’objets dans des images JPEG ou PNG avec Amazon Rekognition. Le résultat est une copie annotée avec les labels et cadres de délimitation détectés.

## Architecture

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
| `index.html` | Interface web. |
| `fichier projet/process_image_add_label.py` | Source de la Lambda de traitement. |
| `fichier projet/get_presigned_url.py` | Source de la Lambda qui génère les URLs présignées. |
| `Cloudformation file/infrastructure-vision-craft.yml` | Infrastructure AWS complète. |
| `deploy.ps1` | Déploiement sous PowerShell. |
| `deploy.sh` | Déploiement sous Bash. |
| `DEPLOYMENT.md` | Instructions de déploiement détaillées. |

## Prérequis

- AWS CLI connecté à un compte AWS (`aws login` ou `aws configure`).
- Droits IAM pour CloudFormation, Lambda, IAM, S3 et Rekognition.
- Une couche Lambda compatible **Python 3.11** qui contient Pillow. Son ARN est obligatoire.

## Déploiement

Sous PowerShell :

```powershell
.\deploy.ps1 -PillowLayerArn "arn:aws:lambda:us-east-1:123456789012:layer:my-pillow-layer:1"
```

Sous Bash :

```bash
export PILLOW_LAYER_ARN='arn:aws:lambda:us-east-1:123456789012:layer:my-pillow-layer:1'
bash ./deploy.sh
```

Les scripts empaquettent les deux fichiers Python, les publient dans un bucket d’artefacts privé, déploient la stack, remplacent temporairement le marqueur d’URL par l’URL générée de la Lambda et publient le frontend dans S3. Les fichiers source restent conservés dans le projet.

Pour restreindre CORS après la démo, passez l’URL du site S3 comme `AllowedOrigin` au lieu de `*`.
