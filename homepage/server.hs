{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Applicative ((<$>), (<*>), (<*))
import Control.Monad (void, forever)
import Control.Concurrent (forkIO)
import System.IO (hClose)
import System.Environment (getArgs)
import System.Posix.User (
	getUserEntryForName, getGroupEntryForName,
	userID, groupID, setUserID, setGroupID)
import Network (PortID(..), listenOn, accept)

import ShowPage (showPage, initLock)

main :: IO ()
main = do
	l <- initLock
	addr : _ <- getArgs
	soc <- listenOn (PortNumber 80) <* setHomepageID
	forever $ accept soc >>= void . forkIO
		. ((>>) <$> showPage l addr <*> hClose) . (\(h, _, _) -> h)
	where setHomepageID = do
		getGroupEntryForName "homepage" >>= setGroupID . groupID
		getUserEntryForName "homepage" >>= setUserID . userID
