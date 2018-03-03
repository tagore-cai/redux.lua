redux = {}
(function(this)

    local ActionTypes = {
        INIT= '@@redux/INIT'
    }

function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

    local function indexOf(arr,arg)
        for i,v in ipairs(arr) do
            if v == arg then
                return i
            end
        end
    end

    local function map( arr, func )
        local _tmp = {}
        for i,v in ipairs(arr) do
            table.insert(_tmp,func(v,i,arr))
        end
        return _tmp
    end

    local function reduce( arr, func, init )
        local _prev = init or arr[1]
        local _lens = #arr
        for i=2, _lens do
            _prev = func(_prev,arr[i],i,arr)
        end
        return _prev 
    end

    local function createStore( reducer, preloadedState, enhancer )
        if type(preloadedState) == "function" and enhancer == nil then
            enhancer = preloadedState
            preloadedState = nil
        end
        if enhancer ~= nil then
            if type(enhancer) ~= "function" then
                error("Expected the enhancer to be a function.")
            end
            return enhancer(createStore)(reducer,preloadedState)
        end
        if type(reducer) ~= "function" then
            error("Expected the enhancer to be a function.")
        end
        local currentReducer = reducer;
        local currentState = preloadedState;
        local currentListeners = {};
        local nextListeners = currentListeners;
        local isDispatching = false;

        local function ensureCanMutateNextListeners()
            if nextListeners == currentListeners then
                nextListeners = clone(currentListeners)
            end
        end

        local function getState( )
            return currentState
        end

        local function subscribe(listener)
            if type(listener) ~= "function" then
                error("Expected listener to be a function.")
            end
            local isSubscribed = true;
            ensureCanMutateNextListeners();
            table.insert(nextListeners,listener);
            return function ()
                if not isSubscribed then
                    return
                end
                isSubscribed = false
                ensureCanMutateNextListeners();
                local index = indexOf(nextListeners,listener)
                table.remove(nextListeners, index)
            end
        end

        local function dispatch( action )
            if type(action) ~= "table" then
                error('Actions must be plain objects. ' + 'Use custom middleware for async actions.');
            end
            if  action.type == nil then
                error('Actions may not have an undefined "type" property. ' + 'Have you misspelled a constant?');
            end
            if isDispatching then
                error('Reducers may not dispatch actions.');
            end
            isDispatching = true;
            currentState = currentReducer(currentState, action);
            isDispatching = false;
            currentListeners = nextListeners;
            local listeners = currentListeners
            for i,listener in ipairs(listeners) do
                listener()
            end
            return action
        end

        local function replaceReducer( nextReducer )
            if type(nextReducer) ~= "function" then
                error('Expected the nextReducer to be a function.');
            end
            currentReducer = nextReducer
            dispatch({type=ActionTypes.INIT})
        end

        local function observable()
            local outerSubscribe, ref = subscribe
            local ref = {
                subscribe = function ( observer )
                    if type(observer) ~= "table" then
                        error('Expected the observer to be an table.');
                    end
                    local function observeState ()
                        if observer.next then
                            observer.next()
                        end
                    end
                    local unsubscribe = outerSubscribe(observeState);
                    return { unsubscribe = unsubscribe };
                end
            }
            return ref
        end
        dispatch({ type= ActionTypes.INIT });
        return {
            dispatch = dispatch,
            subscribe = subscribe,
            getState = getState,
            replaceReducer = replaceReducer
        }
    end

    local function compose( func )
        if #func == 0 then
            return function ( arg )
                return arg
            end
        end
        if #func == 1 then
            return func[1]
        end
        return reduce(func,function ( a, b )
            return function ( ... )
                return a(b( ... ))
            end
        end)
    end

    local function applyMiddleware(...)
        local middlewares = { ... }
        return function ( createStore )
            return function ( reducer, preloadedState, enhancer )
                local store = createStore( reducer, preloadedState, enhancer )
                local _dispatch = store.dispatch
                local chain = {}
                local middlewareAPI = {
                    getState = store.getState,
                    dispatch = function(action) 
                        return _dispatch(action);
                    end
                }
                chain = map( middlewares, function (middleware) 
                    return middleware(middlewareAPI);
                end);
                _dispatch = compose(chain)(store.dispatch);
                local ref = clone(store)
                ref.dispatch = _dispatch
                return ref
            end
        end
    end

    if not this.init then
        this.createStore = createStore
        this.applyMiddleware = applyMiddleware
        this.init = true
    end

end)(redux)

local function reduxLog(_ref)
    local dispatch, getState = _ref.dispatch,  _ref.getState;
    return function (next)
        return function (action)
            local _prev = getState()
            local nextAction =  next(action);
            local _curren = getState()
            print("prev state:", _prev, "current state:", _curren)
            return nextAction
        end;
    end;
end

local function reduxThunk(_ref)
    local dispatch, getState = _ref.dispatch,  _ref.getState;
    return function (next)
        return function (action)
	        if type(action) == 'function' then
	          return action(dispatch, getState, extraArgument);
            end
	        return next(action);
        end;
    end;
end;

local store = redux.createStore(function (state,action)
    local state = state or 0
    if action.type == "inc" then
        return state + 1
    elseif action.type == "dec" then
        return state - 1
    else
        return state
    end
end,redux.applyMiddleware(reduxThunk,reduxLog))

store.subscribe(function ()
    print(" 1 ")
end)

store.dispatch({type="inc"})
store.dispatch({type="inc"})
store.dispatch({type="inc"})
store.dispatch({type="inc"})
store.dispatch({type="dec"})
store.dispatch({type="inc"})