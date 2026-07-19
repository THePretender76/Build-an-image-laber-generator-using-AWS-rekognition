# VisionCraft AI

Application web de détection d’objets dans des images JPEG ou PNG avec Amazon Rekognition. Le résultat est une copie annotée avec les labels et cadres de délimitation détectés.

## Architecture

1. Le navigateur charge `index.html` depuis le bucket S3 frontend.
2. Il demande à la Lambda URL une URL S3 présignée pour envoyer l’image.
3. L’image est envoyée dans le bucket S3 d’entrée.
4. L’événement `ObjectCreated` déclenche la Lambda de traitement.
5. La Lambda utilise Rekognition et Pillow, puis écrit l’image annotée dans le bucket de sortie.
6. Le navigateur vérifie périodiquement la disponibilité de l’image et obtient une URL présignée GET pour l’afficher.

Le diagramme importable est disponible dans `visioncraft-architecture.drawio`.

## Fichiers utiles

| Fichier | Rôle |
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
