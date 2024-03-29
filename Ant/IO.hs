{-# LANGUAGE PatternGuards #-}

module Ant.IO 
    ( GameSettings (..)
    , Content (..)
    , SquareContent
    , Direction (..)
    , Order 
    , Player
    , readSettings
    , gameLoop
    , defaultSettings

    , playerAnt     
    , playerHill 

    , containsAnt
    , containsDeadAnt
    , containsHill
    , containsFood
    , containsWater
    )
    
where
 
import Ant.Point 
 
import Data.Maybe
import Control.Monad.State
import System.IO
import Data.IORef
import Ant.Util

import System.CPUTime
import Text.Printf

data Direction = North | East | South | West deriving (Show, Eq, Enum)
type Player = Int

type Order   = (Point, Direction)
data Content = Water   
             | Food   
             | Hill  !Player
             | Ant   !Player 
             | DeadAnt !Player  
      deriving (Show, Eq)

type SquareContent = (Point, Content)             

data GameSettings = GameSettings
     { loadTime :: !Int
     , turnTime :: !Int
     , mapDimensions :: !Size
     , maxTurns      :: !Int
     , viewRadius2   :: !Int
     , attackRadius2 :: !Int
     , spawnRadius2  :: !Int
     , playerSeed    :: !Int
     } deriving Show
     

defaultSettings :: GameSettings
defaultSettings = makeSettings []

makeSettings :: [Setting] -> GameSettings
makeSettings settings = GameSettings 
    { loadTime          = setting 3000 "loadtime"
    , turnTime          = setting 1000 "turntime"
    , mapDimensions     = fromMaybe (Size 60 90) (liftM2 Size (find "cols") (find "rows"))
    , maxTurns          = setting 1000 "turns"
    , viewRadius2       = setting 55 "viewradius2"
    , attackRadius2     = setting 5 "attackradius2"
    , spawnRadius2      = setting 1 "spawnradius2"
    , playerSeed        = setting 0 "player_seed"
    }
    
    where
       find     = (`lookup` settings)
       setting d = (fromMaybe d) . find               
            
playerAnt :: Int -> Content -> Bool
playerAnt p (Ant p')  = p == p' 
playerAnt _ _           = False
          
playerHill :: Int -> Content -> Bool
playerHill p (Hill p')  = p == p' 
playerHill _ _           = False                 
			 
containsAnt :: Content -> Bool
containsAnt (Ant _) = True
containsAnt _ 	  = False

containsDeadAnt :: Content -> Bool
containsDeadAnt (DeadAnt _) = True
containsDeadAnt _     = False

containsHill :: Content -> Bool
containsHill (Hill _)  = True 
containsHill _         = False  

containsFood :: Content -> Bool
containsFood Food  = True 
containsFood _     = False  

containsWater :: Content -> Bool
containsWater Water  = True 
containsWater _     = False  
			 
orderString :: Order -> String
orderString (Point c r, dir) = "o " ++ (show r) ++ " " ++ (show c) ++ " " ++ (dirString dir)
    where
        dirString North = "N"
        dirString East  = "E"
        dirString South = "S"
        dirString West  = "W"
             

expectLine :: String -> IO ()
expectLine  str = do
    line <- getLine 
    if (line /= str)
       then hPutStrLn stderr ("Expected: " ++ str ++ " got: " ++ line)
       else return ()

                
readSettings :: IO GameSettings
readSettings = do
    n <- liftM readTurn getLine
    settings <- readLines stdin readSetting
    
    return (makeSettings settings)
    

readTurn :: String -> Maybe Int
readTurn str | ["turn", value] <- (words str) =  maybeRead value 
         | otherwise                   = Nothing


readContent :: String -> Maybe SquareContent
readContent str | (c : args) <- (words str) = (mapM maybeRead args) >>= content' c
                | otherwise                 = Nothing
    where 
       content' "a" [r, c, p] = at r c (Ant p)    
       content' "h" [r, c, p] = at r c (Hill p)
       content' "w" [r, c]    = at r c Water
       content' "f" [r, c]    = at r c Food
       content' "d" [r, c, p] = at r c (DeadAnt p)
            
       content' _   _         = Nothing
       
       at r c o = Just (Point c r, o)


maybeLine :: IO (Maybe String)
maybeLine = do
    end <- hIsEOF stdin
    if end then return Nothing
           else liftM Just getLine
               

beginTurn :: IO ()
beginTurn = do
    putStrLn "go"
    hFlush stdout
    

gameLoop :: (MonadIO m) => (Int -> [SquareContent] -> m [Order]) ->  m ()
gameLoop turn = gameLoop' 0.0 where

    gameLoop' total = do
        liftIO beginTurn

        line <- liftIO maybeLine 
        let n = line >>= readTurn
                
        when (isJust n) $ do
            
            start <- liftIO getCPUTime
            content <- liftIO $ readLines stdin readContent
            orders <- turn (fromJust n) content
            
            liftIO $ mapM_ (putStrLn . orderString)  orders
                    
            end <- liftIO getCPUTime
            let diff = (fromIntegral (end - start)) / (10^12)

            let total' = total + diff
            liftIO $ hPrintf stderr "Turn %d complete: %0.4f sec, %0.4f total\n" (fromJust n) (diff :: Float) (total' :: Float)
                
            gameLoop'  total' 
            
            
        
        