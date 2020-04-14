# Déployer notre carte web statique depuis AWS S3 et CloudFront

## Pré-requis

Avant de commencer il faut installer la **AWS Command Line Interface**

=== "Linux"
    ```bash
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    ```

=== "OSX"
    ```bash
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
    ```

=== "Windows"
    1. [Descargamos el AWS CLI MSI installer for Windows (64-bit)][1]
    2. Ejecutamos el programa y seguimos las instrucciones

Créer une clé d’accès pour pouvoir configurer le client. Pour cela : 

1. Aller à <https://console.aws.amazon.com/iam/home#/security_credentials>
2. Cliquer sur **Clés d'accès (ID de clé d'accès et clé d'accès secrète)**
3. Télecharger un ficher de clé

Configurer le client avec les clés téléchargées 

```bash
aws configure
```

## Creamos nuestro Bucket y subir nuestras teselas ya creadas

Vamos a crear nuestro bucket y llamarlo **arbres-tiles**

```sh
aws s3 mb s3://arbres-tiles
```

Vamos a subir nuestras teselas a el bucket. Tenemos que tener en cuenta, al 
igual que lo tuvimos con `serve` y `nginx` de indicarle a **AWS S3** la siguiente cabecera
`--content-encoding gzip` 

```sh
aws s3 sync ./tiles s3:///arbres-tiles --content-encoding gzip
```

## Bucket Policy

Creamos un archivo en la carpeta **aws/policy.json** donde permitimos el acceso de
lectura al público

```json
{
  "Version": "2012-10-17",
  "Id": "Policy1514682206318",
  "Statement": [
    {
      "Sid": "Stmt1514682202401",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::arbres-tiles/*"
    }
  ]
}
```

Y aplicamos la configuración con el siguiente comando:

```sh
aws s3api put-bucket-policy --bucket arbres-tiles --policy file://aws/policy.json 
```

## CORS

Creamos un archivo en la carpeta **aws/cors.json** donde permitimos el todas las 
solicitudes GET desde cualquier origen:

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedHeaders": ["Authorization"],
      "AllowedMethods": ["GET"],
      "MaxAgeSeconds": 3000
    }
  ]
}
```

Y aplicamos la configuración con el siguiente comando:

```sh
aws s3api put-bucket-cors --bucket arbres-tiles --cors-configuration file://aws/cors.json
```

[1]: https://awscli.amazonaws.com/AWSCLIV2.msi