{-# LANGUAGE OverloadedStrings #-}
module Kafka.Producer where
import Kafka.Types
import Data.ByteString.Char8
import qualified Data.ByteString.Char8 as B
import Network
import Data.Serialize.Put
import Data.Digest.CRC32
import System.IO

produceRequestID :: Integer
produceRequestID = 0

data ProducerSettings = ProducerSettings Topic Partition

encode :: ByteString -> ByteString
encode message = runPut $ do
  putMessageMagic
  putWord32be (crc32 message)
  putByteString message
  where putMessageMagic = putWord8 0

putMessage :: ByteString -> Put
putMessage message = do
  let encoded = encode message
  putWord32be $ fromIntegral (B.length encoded)
  putByteString encoded

produce :: ProducerSettings -> ByteString -> IO ()
produce settings message = do
  h <- connectTo "localhost" $ PortNumber 9092
  B.hPut h req
  hFlush h
  hClose h
  where
    m = runPut $ putMessage message
    body = runPut $ produceRequest settings m
    req = runPut $ do
      putWord32be $ fromIntegral (B.length body)
      putByteString body

produceRequest ::  ProducerSettings -> ByteString -> Put
produceRequest settings m = do
  putWord16be 0
  putTopic settings
  putPartition settings
  putMessages m

putTopic ::  ProducerSettings -> Put
putTopic (ProducerSettings (Topic t) _) = do
  putWord16be $ fromIntegral (B.length t)
  putByteString t

putPartition ::  ProducerSettings -> Put
putPartition (ProducerSettings _ (Partition p)) = putWord32be $ fromIntegral p

putMessages ::  ByteString -> Put
putMessages m = do
  putWord32be $ fromIntegral (B.length m)
  putByteString m

