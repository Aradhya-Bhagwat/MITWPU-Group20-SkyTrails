flowchart TD

    subgraph UI["UI Layer"]
        %% ViewControllers handle the views and user input
        VC[ViewControllers]
    end


    subgraph APP["Application Layer"]
        %% Coordinator manages the navigation flow between ViewControllers
        COORD[Coordinator]
        
        %% Managers encapsulate domain-specific business logic 
        MAN[
            Managers:  
        1.Watchlist     
2.Home  
        3.Identification]
    end



    subgraph DATA["Local Persistence"]
        %% Services act as repositories, fetching and preparing data
        SVC[Services]
        
        %% SwiftData container providing context for CRUD operations
        STORE[ModelContainer + Context]
        
        %% Schema models mapping to the local SwiftData storage
        MODELS[SwiftData Models]
    end




    subgraph BACKEND["Supabase Backend"]
        %% Handles user authentication and sessions
        AUTH[Auth]
        
        %% Main Supabase SDK client wrapper
        SB[Client]
        
        %% Remote PostgreSQL database
        PG[(Postgres)]
        
        %% Cloud storage for media/images
        ST[(Storage)]
        
        %% WebSocket connections for live data syncing
        RT[(Realtime)]
    end


    %% UI requests data/actions from Application logic
    UI --> APP
    
    %% Application logic fetches/saves via Local Persistence
    APP --> DATA
    
    %% Persistence saves directly to SwiftData schema
    DATA --> MODELS
    
    %% Application layer manages external cloud synchronization
    APP --> BACKEND
    
    %% Supabase SDK interacts with Database & Storage
    SB --> PG & ST
    
    %% Auth service ties directly to remote Database policies
    AUTH --> PG
    
    %% Realtime subscriptions sync data live from the Postgres DB
    RT --> PG