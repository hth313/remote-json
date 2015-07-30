{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RankNTypes #-}

module Spec where

import           Data.Aeson
import           Data.Aeson.Types
import           Data.Maybe

import           Data.Text(Text, append, pack, unpack)
import qualified Data.Text.IO as TIO
import qualified Data.Text.Lazy as LT
import           Data.Text.Lazy.Encoding(decodeUtf8)

import           Control.Monad (when)
import           Control.Monad.Remote.JSON.Router
import           Control.Monad.Remote.JSON.Types -- for now
import           Data.Attoparsec.ByteString
import           Test (readTests, Test(..))

f :: Call a -> IO a
f (Method "subtract" (List [Number a,Number b]) _) = return $ Number (a - b)
f (Method "subtract" (Named xs) _)
        | Just (Number a) <- lookup "minuend" xs
        , Just (Number b) <- lookup "subtrahend" xs
        = return $ Number (a - b)
f (Method "sum" (List xs) _) = return $ Number $ sum $ [ x | Number x <- xs ]
f (Method "sum" None _) = return $ Number $ 0
f (Method "get_data" None _) = return $ toJSON [String "hello", Number 5]
f (Notification "update" _) = return $ ()
f (Notification "notify_hello" _) = return $ ()
f (Notification "notify_sum" _)   = return $ ()

--f (Method nm args _) = fail $ "missing method : " ++ show (nm,args)
--f (Notification nm args) = fail $ "missing notification : " ++ show (nm,args)

-- Avoid skolem
newtype C = C (forall a . Call a -> IO a)

main = do
  tests <- readTests "tests/spec/Spec.txt"
  res <- sequence 
        [ do when (i == 1) $ do
                putStr "#" 
                TIO.putStrLn $ testName
             putStrLn $ ("--> " ++) $ LT.unpack $ decodeUtf8 $ encode v_req
             r <- router sequence f (Send v_req)
             case r of
               Nothing -> return ()
               Just v_rep -> do
                   putStrLn $ ("<-- " ++) $ LT.unpack $ decodeUtf8 $ encode v_rep
             r <- if (r /= v_expect) 
                  then do putStrLn $ ("exp " ++) $ LT.unpack $ decodeUtf8 $ encode v_expect
                          return $ Just (i,testName)
                  else return Nothing
             putStrLn ""
             return r
        |  (Test testName subTests) <- tests
        ,  (i,(v_req,v_expect)) <- [1..] `zip` subTests
        ]
  let failing = [ x | Just x <- res ]
  if (null failing)
  then putStrLn $ "ALL " ++ show (length res) ++ " TEST(S) PASS"
  else do 
     putStrLn $ show (length failing) ++ " test(s) failed"
     putStrLn $ unlines $ map show failing