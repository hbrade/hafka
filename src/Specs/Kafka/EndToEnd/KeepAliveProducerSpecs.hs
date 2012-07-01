module Specs.Kafka.EndToEnd.KeepAliveProducerSpecs where
import Control.Concurrent.MVar
import Control.Monad
import Kafka.Consumer
import Kafka.Producer
import Kafka.Producer.KeepAlive
import Kafka.Types
import Network.Socket(sClose)
import Specs.IntegrationHelper
import System.Timeout
import Test.HUnit
import Test.Hspec.Monadic
import Test.QuickCheck
import Test.QuickCheck.Monadic

keepAliveProducerProduces :: Stream -> Message -> Property
keepAliveProducerProduces stream message = monadicIO $ do
      let (testProducer, testConsumer) = coupledProducerConsumer stream
      result <- run newEmptyMVar

      p <- run $ keepAliveProducer testProducer
      run $ produce p [message]
      run $ recordMatching testConsumer message result

      run $ waitFor result message (killSocket' p)

killSocket' :: KeepAliveProducer -> IO ()
killSocket' p = do
  r <- timeout 100000 $ takeMVar (kapSocket p)
  case r of
    (Just s) -> do
      sClose s
      putMVar (kapSocket p) s
    Nothing -> error "timed out whilst trying to kill the socket"

