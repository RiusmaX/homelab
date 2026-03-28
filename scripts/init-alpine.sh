#!/with-contenv bash
# Installation des dépendances nécessaires pour mkclean dans les conteneurs Alpine
echo "Installation des dépendances pour mkclean..."
apk add --no-cache libc6-compat gcompat
