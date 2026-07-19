# Déploiement AWS

## Avant de commencer

1. Connectez AWS CLI à votre compte :

   ```powershell
   aws login
   ```

2. Créez ou fournissez une couche Lambda contenant **Pillow**, compatible avec le runtime `python3.11` et l’architecture Lambda choisie. Copiez son ARN.

3. Vérifiez que votre compte peut utiliser Amazon Rekognition dans `us-east-1`.

## Déployer avec PowerShell

Depuis la racine du projet :

```powershell
.\deploy.ps1 -PillowLayerArn "arn:aws:lambda:us-east-1:123456789012:layer:my-pillow-layer:1"
```

Le script :

- déploie `Cloudformation file/infrastructure-vision-craft.yml` ;
- archive `fichier projet/process_image_add_label.py` et `fichier projet/get_presigned_url.py` ;
- publie ces archives dans un bucket d’artefacts privé créé automatiquement ;
- récupère l’URL de la Lambda de génération d’URL présignées ;
- insère cette URL dans une copie temporaire de `index.html` ;
- publie cette copie dans le bucket frontend ;
- affiche l’URL publique du site.

Le fichier `index.html` local conserve un marqueur d’URL et peut donc être redéployé sans modification manuelle.

## Déployer avec Bash

Prérequis : Bash (Linux, macOS, Git Bash ou WSL), Python 3 et AWS CLI.

```bash
export PILLOW_LAYER_ARN='arn:aws:lambda:us-east-1:123456789012:layer:my-pillow-layer:1'
bash ./deploy.sh
```

Variables optionnelles : `AWS_REGION` (défaut : `us-east-1`), `STACK_NAME`, `PROJECT_PREFIX` et `ALLOWED_ORIGIN`.

## Après le déploiement

1. Ouvrez l’URL affichée par le script.
2. Envoyez une image JPEG.
3. Vérifiez le traitement dans les logs CloudWatch de la fonction `<prefix>-process-image` si le résultat n’apparaît pas après environ une minute.

## CORS et sécurité

La valeur par défaut `AllowedOrigin=*` est adaptée à une démonstration. Pour un site exposé, mettez à jour la stack avec l’URL exacte de votre frontend et évitez de laisser la Lambda Function URL accessible sans contrôle d’accès.
