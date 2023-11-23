#!/bin/bash
# Mainainer Ludovic Tual @ 2023.

# This script is a certificate toolbox.

# Colors :
Normal='\033[0m'          # Text Reset
BWhite='\033[1;37m'       # Bold White
White='\033[0;37m'        # White


fn_banner ()
{
echo "╔═════════════════════════════════╗"
echo "║   SSL/TLS Certificate Toolbox   ║"    
echo "╚═════════════════════════════════╝"
echo ""
}

fn_help ()
{
echo "$0 is a tool designed to help the management of certs."
echo ""
echo "Usage:" 
echo "        -d/--domain website.com OR -f/--file website.crt" 
echo ""
echo "Option:"
echo "        -k/--key private.key --> Verify if key is related to the certificate."
echo "        --dig                --> Search for keyfile in HOME and try to match the cert." 
echo "        -g                   --> Generate fullchain certificate." 
echo "        --install            --> Install $0 like a software on your system."  
echo ""
}

fn_install ()
{
echo ""  
echo "Bip Boup Bop.. install not implemented"
echo ""
exit 0
}


fn_arg_check ()
{
if [[ -z "$1" ]];
  then
   fn_banner  
   echo " ❌ Missing arg.. Exit."
   echo ""
   fn_help
   exit 0
fi
}

# Args decoder : 
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--domain)
      DOMAIN_NAME=$2
      RUNMODE=1
      fn_arg_check $2
      shift 2
      ;;
    -f|--file)
      CERT_FILE=$2
      RUNMODE=1
      fn_arg_check $2
      shift 2
      ;;
    -k|--key)
      KEY_FILE=$2
      echo "$2" > key_list.tmp
      SUBMODE=1
      fn_arg_check $2
      shift 2
      ;;
    --dig)
      SUBMODE=2
      DIG_KEY=true
      shift 1
      ;;
    -g|--generate-full-chain)
      GEN_FULL=true
      shift 1
      ;;
     --install)
      fn_install
      shift 1
      ;; 
     -h|--help)
      fn_banner
      fn_help
      exit 1
      ;;     
    -*|--*)
      fn_banner  
      fn_help
      echo " ❌ Unknown option $1"
      echo ""
      exit 1
      ;;
    *)
      fn_banner
      fn_help
      exit 0
      ;;
  esac
done


fn_forge_fullchain ()
{
if [ $GEN_FULL ];
  then
   echo "•••••••••••••••••••••••••••••••••••"
   echo ""
   echo -e " 🏗️  - Generate fullchain cert file : $BWhite"$ISSUED_CRT"_fullchain.crt $Normal" 
   cat cert_*.crt > $ISSUED_CRT"_fullchain.crt"
   echo ""
fi
}


fn_key_digger ()
{
find -E $HOME -iregex ".*\.(key|pem)" 2>/dev/null | grep -v ' ' > key_list.tmp
}

# Mode that compare KEY and CRT Files.
fn_certificate_compare ()
{
echo "•••••••••••••••••••••••••••••••••••"
echo ""

# Get MD5 Value of CRT.
MD5_CRT=$(openssl x509 -in cert_0.crt -pubkey -noout -outform pem  2>/dev/null | md5)

# Read the list of keys to check. 
while read -r KEYFILE 
do
   # Get MD5 Value of CRT.
   MD5_PK=$(openssl pkey -in $KEYFILE -pubout -outform pem -passin pass:1234 2>/dev/null | md5)
  
if [[ "$MD5_CRT" == "$MD5_PK" ]];
  then
   echo -e " ✅ Congrats.. $BWhite$KEYFILE$Normal match the certificate."
   echo ""
   echo -e " 🔏 MD5sum Certificate : $BWhite$MD5_CRT$Normal"
   echo -e " 🔐 MD5sum Secret key  : $BWhite$MD5_PK$Normal"
   echo ""
   return
  else 
   echo " 🔶 Trying.. But the key didn't match the certificate."
fi
done < key_list.tmp
echo " ❌ Sorry.. Unable to find a key that match the certificate."
echo ""
}

fn_get_basic_infos ()
{
SERVER_DATE_CRT=$(openssl x509 -in cert_0.crt -noout -enddate | cut -d"=" -f2)
ISSUED_CRT=$(openssl x509 -in cert_0.crt  -noout -text | grep "Subject:" | awk '{print $NF}' | cut -d'=' -f2)

echo -e " 🌏 - Certificate for domain : $BWhite$DOMAIN_NAME$Normal" 
echo -e " 👑 - Is issued for CN : $BWhite$ISSUED_CRT$Normal"
echo -e " 🔥 - Expire after : $BWhite$SERVER_DATE_CRT$Normal"
echo ""
}

fn_get_chain ()
{
echo "•••••••••••••••••••••••••••••••••••"
echo ""
# Get URL of the CA Issuer.
INTER_URL=$(openssl x509 -in cert_0.crt  -noout -text | grep "CA Issuers" | cut -d":" -f2,3)

# Check if CA Issuer has been found. 
if [[ -z "$INTER_URL" ]]
  then  
   echo " ❌ Issuer can't be found in cert.. Exit."
   echo ""
   exit 0
fi

# Start at deeph 1 for loop rotation.
DEEPH=1
# Loop to explore the deeph of the certifcates chain.
while [[ ! -z "$INTER_URL" ]]; do
# Download the intermediates certs.
wget -q -O cert_$DEEPH.crt $INTER_URL && openssl x509 -in cert_$DEEPH.crt -inform DER -out cert_$DEEPH.crt && \
echo -e " 📝 - $BWhite cert_$DEEPH.crt $Normal has been generated for :$BWhite $INTER_URL $Normal" 
cat cert_$DEEPH.crt >> bundle.crt

# openssl x509 -in cert_0.crt  -noout -enddate 
# openssl verify -untrusted cert_1.crt cert_0.crt

# openssl verify -untrusted bundle.crt cert_0.crt
# cat cert_2.crt cert_1.crt > bundle.crt 

# Detect the next CA URL Issuers.
INTER_URL=$(openssl x509 -in cert_$DEEPH.crt -noout -text | grep "CA Issuers" | cut -d":" -f2,3)
# Check if max deeph is reached. 
if [[ -z "$INTER_URL" ]]
  then
   echo ""  
   echo " 🛝 - Certificate chain has reached maximum depth.. "
   echo "" 
 #  echo "Validity : "$(openssl verify -untrusted bundle.crt cert_0.crt | awk '{print $NF}')
fi
# Increase rotate loop and continue.
DEEPH=$((DEEPH+1))
done
}


# Download crt file or get it from local.
fn_get_cert ()
{

# Check if at leat one cert source is feeded.
if [[ -z "$CERT_FILE" && -z "$DOMAIN_NAME" ]];
  then  
   echo " ❌ No cert has been provided.. Exit."
   echo ""
   fn_help
   exit 0
fi

# Is domain valid ? (check)
# Is file valide ? (check)


if [[ ! -z "$DOMAIN_NAME" ]]
  then
   true | openssl s_client -connect $DOMAIN_NAME:443 -servername "$DOMAIN_NAME" 2>/dev/null | openssl x509 > cert_0.crt
  else
   DOMAIN_NAME="Not Provided."
   cp $CERT_FILE cert_0.crt
fi
}

fn_run_submode ()
{
case $SUBMODE in
  1)
   # Compare mode.
   fn_certificate_compare $KEY_FILE
    ;;
  2)
    # Dig mode.
   fn_key_digger
   fn_certificate_compare
    ;;
esac
}

# Runmode trigger the differents actions.
fn_run_mode ()
{
case $RUNMODE in
  1)
   # Regular mode
    fn_banner
    fn_get_cert 
    fn_get_basic_infos
    fn_run_submode
    fn_get_chain
    fn_forge_fullchain
    ;;
  2)
    # Compare mode.
    fn_banner
    fn_get_cert
    fn_get_basic_infos
    ;;
esac
}

# Clean workspace and start the script.. LAUNCH !!
rm -f bundle.crt cert_*.crt && fn_run_mode






 


