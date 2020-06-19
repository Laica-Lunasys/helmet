#!/bin/bash
set -e
if [ "$1" = "" ] || [ "$2" = "" ]; then
    echo "Usage: helmet.sh <install|upgrade|delete|switch|generate|template> <branch>" && exit 1
fi

if [ ! -e "$PWD/APPCONFIG.sh" ]; then
    echo "E: APPCONFIG.sh not found."
    exit 1
fi

source APPCONFIG.sh $2

_set() {
    if [ "${#CHART_SET[@]}" != "0" ]; then
        echo "--set $(echo ${CHART_SET[@]} | sed -e 's/\ /,/g')"
    fi
}

_values() {
    if [ "${#CHART_VALUES[@]}" != "0" ]; then
        echo "--values $(echo ${CHART_VALUES[@]} | sed -e 's/\ /,/g')"
    fi
}

_check_repo() {
    if [ "$CHART" != "." ]; then
        if [ "$HELM_REPO_URL" = "" ]; then
            echo "E: HELM_REPO_NAME not specified."
            exit 1
        fi
        if ! helm repo list -o yaml | grep -qE "\s${HELM_REPO_NAME}$"; then
            helm repo add $HELM_REPO_NAME $HELM_REPO_URL
            helm repo update
        fi
    fi
}

if [ "$1" = "details" ]; then
    echo "CHART: ${CHART}"
    echo "APP_NAME: ${APP_NAME}"
    echo "NAMESPACE: ${NAMESPACE}"
    if [ ! -z "$IMAGE_TAG" ]; then
        echo "IMAGE_TAG: ${IMAGE_TAG}"
    fi
fi

if [ "$1" = "install" ]; then
    _context $_branch
    _check_repo
    helm install $APP_NAME $CHART \
        --namespace=$NAMESPACE \
        $(_set $2) \
        $(_values $2)
fi

if [ "$1" = "upgrade" ]; then
    _context $_branch
    _check_repo
    helm upgrade $APP_NAME $CHART \
        --namespace=$NAMESPACE \
        $(_set $2) \
        $(_values $2)
fi

if [ "$1" = "delete" ]; then
    _context $_branch
    _check_repo
    helm delete $APP_NAME \
        --namespace=$NAMESPACE
fi

if [ "$1" = "switch" ]; then
    _context $_branch
fi

if [ "$1" = "generate" ]; then
    _check_repo
    mkdir -p $PWD/.tmp-chart

    if [ "$CHART" = "." ]; then
        helm package -d $PWD/.tmp-chart/ $CHART
    else
        helm fetch -d $PWD/.tmp-chart/ $CHART
    fi

    if [ ! -e "$PWD/generated" ]; then
        mkdir -p $PWD/generated
    fi

    for f in $(find $PWD/.tmp-chart -mindepth 1 -type f -name '*.tgz'); do
        helm template $APP_NAME $f \
            --namespace=$NAMESPACE \
            --output-dir $PWD/generated \
            $(_set $2) \
            $(_values $2)
    done
    rm -rf $PWD/.tmp-chart/
fi

if [ "$1" = "template" ]; then
    _check_repo
    mkdir -p $PWD/.tmp-chart

    if [ "$CHART" = "." ]; then
        helm package -d $PWD/.tmp-chart/ $CHART
    else
        helm fetch -d $PWD/.tmp-chart/ $CHART
    fi

    for f in $(find $PWD/.tmp-chart -mindepth 1 -type f -name '*.tgz'); do
        helm template $APP_NAME $f \
            --namespace=$NAMESPACE \
            $(_set $2) \
            $(_values $2) \
            2>&1 | vim - -Rc ':set filetype=yaml'
    done
    rm -rf $PWD/.tmp-chart/
fi
