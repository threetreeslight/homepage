{-# LANGUAGE OverloadedStrings, PackageImports #-}

import Control.Applicative
import Control.Arrow
import "monads-tf" Control.Monad.State
import "monads-tf" Control.Monad.Identity
import System.Random
import Crypto.Cipher.AES
import Crypto.Cipher.Types

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Base64 as Base64
import qualified Crypto.Hash.SHA256 as SHA256

keySample :: AES
keySample = initAES ("passwordpassword" :: BS.ByteString)

ivSample :: BS.ByteString
ivSample = "this is iv ivivi"

times :: Int -> (s -> (x, s)) -> s -> ([x], s)
times n _ s | n <= 0 = ([], s)
times n f s = let
	(x, s') = f s
	(xs, s'') = times (n - 1) f s' in
	(x : xs, s'')

randomIv :: RandomGen g => AES -> g -> (BS.ByteString, g)
randomIv a = (BS.pack `first`) . times (blockSize a) random

mkAes :: BS.ByteString -> AES
mkAes = initAES . SHA256.hash

padToLen :: BS.ByteString -> Int -> BS.ByteString
padToLen s n = s `BS.append` BS.replicate
	(n - BS.length s)
	(fromIntegral $ n - BS.length s - 1)

blkSzToLen :: Int -> BS.ByteString -> Int
blkSzToLen b s = (BS.length s `div` b + 1) * b

padding :: Int -> BS.ByteString -> BS.ByteString
padding b = ($) <$> padToLen <*> blkSzToLen b

unpadding :: BS.ByteString -> BS.ByteString
unpadding p = BS.take
	(BS.length p - fromIntegral (BS.last p) - 1) p

encrypt1 :: RandomGen g =>
	AES -> BS.ByteString -> g -> (BS.ByteString, g)
encrypt1 _ "" g = ("[nsc][0]", g)
encrypt1 k s g = let
	(iv, g') = randomIv k g
	cph = Base64.encode . (iv `BS.append`)
		$ encryptCBC k iv (padding (blockSize k) s) in
	("[nsc][" `BS.append` BSC.pack (show $ BS.length cph)
		`BS.append` "]" `BS.append` cph, g')

encrypt :: RandomGen g =>
	AES -> BS.ByteString -> g -> (BS.ByteString, g)
encrypt k s = runState $ BSC.unlines <$> mapM
	(StateT . (Identity .) . encrypt1 k)
	(BSC.lines s)
