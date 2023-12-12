#!/bin/sh

get_file_from_s3() {
  if [[ -z $1 || -z $2 ]]; then
    exit 1
  fi
  export AWS_ENDPOINT_URL=http://${SCALIND_S3_URL}
  export AWS_ACCESS_KEY_ID=${SCALIND_S3_ACCESS_KEY}
  export AWS_SECRET_ACCESS_KEY=${SCALIND_S3_SECRET_KEY}
  aws s3 cp s3://${SCALIND_S3_BUCKET}/$1 $2 || exit 1
}

get_genesis_from_s3() {
    get_file_from_s3 $SCALIND_S3_GENESIS_FILE_PATH ~/configs/genesis.json
    echo "Genesis file downloaded from S3"
}

get_rollup_from_s3() {
    get_file_from_s3 $SCALIND_S3_ROLLUP_FILE_PATH ~/configs/rollup.json
    echo "Rollup file downloaded from S3"
}

DATADIR=/volume/datadir
ARGS="--datadir=$DATADIR"

if [[ -n $SCALIND_S3_URL && -n $SCALIND_S3_ACCESS_KEY && -n $SCALIND_S3_SECRET_KEY && -n $SCALIND_S3_BUCKET && -n $SCALIND_S3_GENESIS_FILE_PATH  ]]; then
  get_genesis_from_s3
fi

if [[ -f ~/configs/genesis.json ]]; then
  if [[ ! -f /volume/datadir/chaindata/mdbx.dat ]]; then
    echo "INFO: Data not found. Initializing from genesis file"
    erigon init $ARGS ~/configs/genesis.json
    echo "INFO: Chain datadir initialized"
  fi
else
  echo "ERROR: Genesis.json should be mounted or S3 connection options should be provided"
  exit 1
fi

if [[ -f /secrets/jwt.txt ]]; then
  ARGS="--l2.jwt-secret=/secrets/jwt.txt $ARGS"
else
  echo "ERROR: File \"/secrets/jwt.txt\" should be present"
  exit 1
fi

if [[ -n $SCALIND_CHAIN_ID ]]; then
  ARGS="--networkid=$SCALIND_CHAIN_ID $ARGS"
else
  echo "ERROR: Variable \"SCALIND_CHAIN_ID\" should be present"
  exit 1
fi

ARGS="--http --http.corsdomain=\"*\" --http.vhosts=\"*\" --http.addr=0.0.0.0 --http.api=web3,debug,eth,erigon,txpool,net,engine --ws --ws.api=debug,eth,erigon,txpool,net,engine --nodiscover --maxpeers=0 --authrpc.vhosts="*" --authrpc.addr=0.0.0.0 --authrpc.port=8551 --authrpc.jwtsecret=./jwt.txt --rollup.disabletxpoolgossip=true $ARGS"

sh -c "erigon $ARGS"