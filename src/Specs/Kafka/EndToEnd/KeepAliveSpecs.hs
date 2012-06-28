module Specs.Kafka.EndToEnd.KeepAliveSpecs where
import Test.QuickCheck
import Kafka.Producer
import Kafka.Consumer
import Kafka.Consumer.KeepAlive
import Kafka.Types
import Control.Concurrent.MVar
import qualified Data.ByteString.Char8 as B
import Test.QuickCheck.Monadic
import Specs.IntegrationHelper
import Control.Concurrent(forkIO)
import Network.Socket(sClose, sIsConnected)
import Control.Monad
import System.Timeout

keepAliveReconectsToClosedSockets :: Stream -> Message -> Property
keepAliveReconectsToClosedSockets stream message = monadicIO $ do
      let (testProducer, testConsumer) = coupledProducerConsumer stream
      result <- run newEmptyMVar

      c <- run (keepAlive testConsumer)
      run $ recordMatching c message result
      run $ killSocket c

      run $ produce testProducer [message]

      run $ waitFor result ("timed out waiting for " ++ show message ++ " to be delivered") (killSocket c)

keepAliveConsumesMultipleMessages :: Stream -> Message -> Message -> Property
keepAliveConsumesMultipleMessages stream m1 m2 = monadicIO $ do
      let (testProducer, testConsumer) = coupledProducerConsumer stream
      result <- run newEmptyMVar

      c <- run (keepAlive testConsumer)
      run $ produce testProducer [m1, m2]
      run $ recordMatching c m2 result

      run $ waitFor result ("timed out waiting for " ++ show m2 ++ " to be delivered") (return ())

recordMatching :: (Consumer c) => c -> Message -> MVar Message -> IO ()
recordMatching c original r = do
  _ <- forkIO $ consumeLoop c go
  return ()

  where
    go :: Message -> IO ()
    go message = when (original == message) $ finish message
    finish :: Message -> IO ()
    finish message = do
              putMVar r message
              killCurrent

killSocket :: KeepAliveConsumer -> IO ()
killSocket c = do
  r <- timeout 100000 $ takeMVar (kaSocket c)
  case r of
    (Just s) -> do
      sClose s
      putMVar (kaSocket c) s
    Nothing -> error "timed out whilst trying to kill the socket"
