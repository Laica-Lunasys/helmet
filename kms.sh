#!/bin/bash
set -e
if [ "$1" = "" ]; then
    echo "Usage: kms.sh <encrypt|decrypt|init|details>" && exit 1
fi

if !(type "gcloud" > /dev/null 2>&1); then
    echo "E: google-cloud-sdk not found."
    exit 1
fi
if [ ! -e "$PWD/KMSCONFIG.sh" ]; then
    echo "E: KMSCONFIG.sh not found."
    exit 1
fi
if [ ! -e "$PWD/secrets" ]; then
    echo "E: secrets directory not found."
    exit 1
fi

source KMSCONFIG.sh

if [ "$1" = "details" ]; then
    echo ":: Current ENV:"
    echo "KMS_PROJECT_ID: ${KMS_PROJECT_ID}"
    echo "KEYRING_NAME: ${KEYRING_NAME}"
    echo "KEYRING_PATH: ${KEYRING_PATH}"
    echo ""

    cd secrets
    echo ":: List of plain :"
    for f in $(find * -type f -not -name '*.enc'); do
        KEY_NAME="${KEY_PREFIX}_$(echo $f | sed -e 's/\.[^\.]*$//' -e 's|/|_|g')"
        echo "- $f ($KEY_NAME)"
    done
    echo ""
    echo ":: List of enc:"
    for f in $(find * -type f -name "*.enc"); do
        echo "- $f"
    done
fi

if [ "$1" = "encrypt" ]; then
    cd secrets
    for PLAIN_FILE_NAME in $(find * -type f -not -name '*.enc'); do
        ENC_FILE_NAME=$(echo "${PLAIN_FILE_NAME}.enc")
        KEY_NAME="${KEY_PREFIX}_$(echo $PLAIN_FILE_NAME | sed -e 's/\.[^\.]*$//' -e 's|/|_|g')"
        echo ":: Encrypting..."
        echo "- PLAIN_FILE_NAME: ${PLAIN_FILE_NAME}"
        echo "- ENC_FILE_NAME: ${ENC_FILE_NAME}"
        echo "- KEY_NAME: ${KEY_NAME}"

        # Create key when not exists
        if [ "$(gcloud --project ${KMS_PROJECT_ID} kms keys list --location=global --keyring=${KEYRING_PATH} --format="value(name)" | grep -x ${KEYRING_PATH}/cryptoKeys/${KEY_NAME}; echo $?)" = "1" ]; then
            echo "=> Creating key: ${KEY_NAME}"
            gcloud --project ${KMS_PROJECT_ID} kms keys create ${KEY_NAME} \
                --location=global \
                --keyring=${KEYRING_NAME} \
                --purpose=encryption
        fi

        # Encrypt
        gcloud --project ${KMS_PROJECT_ID} kms encrypt \
            --plaintext-file=$PWD/${PLAIN_FILE_NAME} \
            --ciphertext-file=$PWD/${ENC_FILE_NAME} \
            --location=global \
            --keyring=${KEYRING_NAME} \
            --key=${KEY_NAME}

        echo ":: Encrypted: ${KEY_NAME} (${PLAIN_FILE_NAME} -> ${ENC_FILE_NAME})"
    done
fi

if [ "$1" = "init" ]; then
    echo "=> Creating KEYRING..."
    gcloud --project ${KMS_PROJECT_ID} kms keyrings create ${KEYRING_NAME} \
        --location=global
fi

if [ "$1" = "decrypt" ]; then
    cd secrets
    for ENC_FILE_NAME in $(find * -type f -name '*.enc'); do
        PLAIN_FILE_NAME=$(echo $ENC_FILE_NAME | sed -e 's|.enc||')
        KEY_NAME="${KEY_PREFIX}_$(echo $ENC_FILE_NAME | sed -e 's/\..*.enc//' -e 's|/|_|g')"
        echo ":: Decrypting..."
        echo "- ENC_FILE_NAME: ${ENC_FILE_NAME}"
        echo "- PLAIN_FILE_NAME: ${PLAIN_FILE_NAME}"
        echo "- KEY_NAME: ${KEY_NAME}"

        # Decrypt
        gcloud --project ${KMS_PROJECT_ID} kms decrypt \
            --plaintext-file=$PWD/${PLAIN_FILE_NAME} \
            --ciphertext-file=$PWD/${ENC_FILE_NAME} \
            --location=global \
            --keyring=${KEYRING_NAME} \
            --key=${KEY_NAME}

        echo ":: Decrypted: ${KEY_NAME} (${ENC_FILE_NAME} -> ${PLAIN_FILE_NAME})"
    done
fi
