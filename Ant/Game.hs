module Ant.Game 
     ( GameState(..)
     , Game
     , runGame
     , initialState
     
     , module Ant.Point
     , module Ant.Square
     , module Ant.IO
     , module Ant.Map
     , module Ant.Scenario
     , module Ant.Graph
     , module Ant.Passibility
     
     )
    where

import Control.Monad
import Control.Monad.State.Strict

import qualified Data.Set as S

import Ant.Point
import Ant.IO
import Ant.Map
import Ant.Scenario
import Ant.Square
import Ant.Graph
import Ant.Passibility

import System.Random
import Debug.Trace

type Game a = StateT GameState IO a


data GameState = GameState
    { gameSettings      :: !GameSettings
    , gameMap           :: Map
    , gameGraph         :: Graph
    , gamePass          :: Passibility
    }

 
initialState :: GameSettings -> GameState
initialState settings = GameState 
    { gameSettings    = settings
    , gameMap         = emptyMap unknownSquare (mapDimensions settings) 
    , gameGraph       = emptyGraph (mapDimensions settings) 32
    , gamePass = emptyPassibility (mapDimensions settings) pattern2
    }
 
 


contentSquares :: (Content -> Bool) -> [SquareContent] -> [Point]
contentSquares f content = map fst $ filter (f . snd) content    
          
initRegions :: [SquareContent] -> Graph -> Graph
initRegions content graph = foldr addRegion graph hillRegions where 
    hills = contentSquares (playerHill 0) content
    hillRegions = filter isUnknown hills   
    isUnknown p = invalidRegion == graph `regionAt` p
    
    
modifyGraph :: (Graph -> Graph) -> Game ()
modifyGraph f = modify $ \state -> state { gameGraph = f (gameGraph state) }
 
modifyMap :: (Map -> Map) -> Game ()
modifyMap f = modify $ \state -> state { gameMap = f (gameMap state) }

modifyPass :: (Passibility -> Passibility) -> Game ()
modifyPass f = modify $ \state -> state { gamePass = f (gamePass state) }

updateState :: [SquareContent] -> Game ()
updateState content = do
        
    let ants = contentSquares (playerAnt 0) content
    
    world <- gets gameMap
    radiusSq <- getSetting viewRadius2

    let vis = visibleSet (mapSize world) radiusSq ants
    let dVis = newlyVisible vis world

    n <- gets (numRegions . gameGraph)
    when (n == 0) $ modifyGraph (initRegions content) 
    
    traceShow n $ return ()
    
    let world' = (updateContent content . updateVisibility vis) world

    pass <- gets gamePass 
    let pass' = updatePassibility dVis world' pass

    graph <- gets gameGraph
    let graph' = updateGraph pass' world' graph
    
    
    --let graph' = updateGraph 

    modify $ \gameState -> gameState 
        { gameMap = world'
        , gamePass = pass'
        , gameGraph = graph'
        }

    
processTurn :: Int -> [SquareContent] -> Game [Order]
processTurn n content = do
    liftIO $ putStrLn $ "Processing turn: " ++ (show n) ++ "...\n"
    
    updateState content
    return []
    
    --orders <- liftM (map toEnum . randomRs (0, 3)) (liftIO getStdGen)
    --return $ zip (map fst ants) orders


runGame :: GameState -> IO GameState
runGame = execStateT (gameLoop processTurn)