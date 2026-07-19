# VisionCraft AI

Application web de détection d’objets dans des images JPEG et PNG avec Amazon Rekognition. Elle produit une copie annotée avec les libellés détectés et leurs cadres.

## Architecture

1. Le navigateur charge `index.html` depuis un site web S3.
2. Il demande à une Lambda URL une URL S3 présignée pour envoyer l’image.
3. L’image est déposée dans le bucket S3 d’entrée.
4. L’événement S3 déclenche la Lambda de traitement.
5. La Lambda normalise l’image en JPEG, appelle Rekognition, dessine les résultats avec Pillow et écrit l’image annotée dans le bucket de sortie.
6. Le navigateur vérifie l’état du traitement puis affiche une URL présignée de téléchargement.

<img width="1170" height="1260" alt="Architecture VisionCraft" src="https://github.com/user-attachments/assets/5f197bc5-4a5e-4df5-8761-8bcf6b91e791" />

## Contenu du dépôt

| Fichier | Rôle |
| --- | --- |
| `index.html` | Interface web statique. |
| `fichier projet/process_image_add_label.py` | Lambda de normalisation, détection et annotation. |
| `fichier projet/get_presigned_url.py` | Lambda des URLs S3 présignées. |
| `Cloudformation file/infrastructure-vision-craft.yml` | Infrastructure AWS. |
| `deploy.sh` | Déploiement Bash. |
| `deploy.ps1` | Déploiement PowerShell. |

## Prérequis

- Un compte AWS et AWS CLI connecté : `aws login` ou `aws configure`.
- Autorisations IAM pour CloudFormation, Lambda, IAM, S3 et Rekognition.
- Bash (Git Bash, WSL, Linux ou macOS) et Python 3 disponibles dans le `PATH` pour utiliser `deploy.sh`.
- Une couche Lambda Pillow pour **Python 3.11 / x86_64**, dans la même région que la stack.

Vérifiez l’identité AWS avant de déployer :

```bash
aws sts get-caller-identity --region us-east-1
```

## Créer la couche Pillow

La Lambda utilise Python 3.11 sur x86_64. Pillow contient des composants natifs : la couche doit donc contenir une version Linux compatible. Le moyen le plus simple est AWS CloudShell dans la région `us-east-1`.

```bash
mkdir -p ~/visioncraft-layer/python
cd ~/visioncraft-layer

python3 -m pip install \
  --platform manylinux2014_x86_64 \
  --only-binary=:all: \
  --python-version 3.11 \
  --target python \
  Pillow

zip -r pillow-python311-x86_64.zip python

aws lambda publish-layer-version \
  --region us-east-1 \
  --layer-name visioncraft-pillow-python311 \
  --description "Pillow for VisionCraft / Python 3.11 / x86_64" \
  --zip-file fileb://pillow-python311-x86_64.zip \
  --compatible-runtimes python3.11 \
  --compatible-architectures x86_64 \
  --query 'LayerVersionArn' \
  --output text
```

Copiez l’ARN retourné, par exemple :

```text
arn:aws:lambda:us-east-1:123456789012:layer:visioncraft-pillow-python311:1
```

## Déployer avec Bash

Depuis la racine du projet :

```bash
export PILLOW_LAYER_ARN='arn:aws:lambda:us-east-1:123456789012:layer:visioncraft-pillow-python311:1'
export AWS_REGION='us-east-1'
export ALLOWED_ORIGIN='*'
bash ./deploy.sh
```

Le script crée si besoin un bucket d’artefacts privé, empaquette les deux Lambdas, déploie la stack CloudFormation, configure le frontend avec la Lambda URL, puis affiche l’URL publique du site.

Variables optionnelles :

```bash
export STACK_NAME='visioncraft-stack'
export PROJECT_PREFIX='visioncraft'
```

Après le premier déploiement, vous pouvez restreindre CORS à l’URL exacte du site, puis relancer le script :

```bash
export ALLOWED_ORIGIN='http://visioncraft-frontend-ACCOUNT_ID-us-east-1.s3-website-us-east-1.amazonaws.com'
bash ./deploy.sh
```

## Déployer avec PowerShell

```powershell
.\deploy.ps1 -PillowLayerArn "arn:aws:lambda:us-east-1:123456789012:layer:visioncraft-pillow-python311:1"
```

## Vérifier le déploiement

1. Ouvrez l’URL affichée par le script.
2. Envoyez une image JPEG ou PNG.
3. Attendez la fin de l’analyse et téléchargez l’image annotée.

Si l’analyse reste bloquée, ouvrez **AWS Console → Lambda → `visioncraft-process-image` → Monitor → View CloudWatch logs**. Les erreurs de traitement apparaissent dans le flux le plus récent.

## Mise à jour du projet

Après toute modification de l’un des fichiers Python ou de `index.html`, relancez `bash ./deploy.sh`. Le script publie de nouvelles archives Lambda afin que CloudFormation mette à jour le code.
