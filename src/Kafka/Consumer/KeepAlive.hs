module Kafka.Consumer.KeepAlive where
import Kafka.Consumer
import Kafka.Parsing
import Kafka.Response
import Kafka.Types
import Kafka.Network
import Network.Socket hiding (send, sendTo, recv, recvFrom)
import Network.Socket.ByteString
import System.IO
import qualified Data.ByteString.Char8 as B
import Data.ByteString.Char8(ByteString)
import Data.Serialize.Get
import Control.Concurrent.MVar

data KeepAliveConsumer = KeepAliveConsumer {
    kaConsumer :: BasicConsumer
  , kaSocket :: MVar Socket
  }

instance Consumer KeepAliveConsumer where
  consume c = do
    newC <- withReconnected c
    result <- withSocket newC (\s -> do
        send s $ consumeRequest newC
        readDataResponse' s
      )
    case result of
      (Right r) -> return $! parseMessageSet r newC
      (Left r) -> do 
        print ("error parsing response: " ++ show r)
        return ([], newC)

  getOffset c = getOffset $ kaConsumer c
  getStream c = getStream $ kaConsumer c

  increaseOffsetBy c n = c { kaConsumer = newC }
    where newC = increaseOffsetBy (kaConsumer c) n

withSocket :: KeepAliveConsumer -> (Socket -> IO a) -> IO a
withSocket c f = do
  s <- takeMVar $ kaSocket c
  r <- f s
  putMVar (kaSocket c) s
  return $! r

withReconnected :: KeepAliveConsumer -> IO KeepAliveConsumer
withReconnected c = do
  s <- takeMVar $ kaSocket c
  s' <- reconnectSocket s
  putMVar (kaSocket c) s'
  return $! c

reconnectSocket :: Socket -> IO Socket
reconnectSocket s = do
  c <- sIsConnected s
  if c then
    return s
  else
    connectToKafka

connectToKafka :: IO Socket
connectToKafka = connectTo "localhost" $ PortNumber 9092

readDataResponse' :: Socket -> IO (Either ErrorCode ByteString)
readDataResponse' s = do
  d <- recv s 4096
  let (Right dataLength) = runGet getDataLength d
      rawResponse = B.take dataLength (B.drop 4 d)
      x = parseErrorCode rawResponse
  case x of
    Success -> return $! Right $ B.drop 2 rawResponse
    e -> return $! Left e

keepAlive :: BasicConsumer -> IO KeepAliveConsumer
keepAlive c = do
  s <- connectToKafka >>= newMVar
  return $! KeepAliveConsumer c s

