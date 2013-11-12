id = 0

log = -> # NOP
# log = console.log

class Value then to-string: -> @id

class Vertex extends Value then ->
  @x = @y = void
  @id = id++
  @edges = [] # edges connecting this vertex
  @neighbors = {} # edge -> vertex
  @srobhgien = {} # vertex -> edge
  @player = void # player who occupies this vertex with endpoint, or void

class Edge extends Value then (@0, @1, @bandwidth) ->
  @source = @0
  @target = @1
  @id = id++
  @length = 2
  @0.edges.push this
  @1.edges.push this
  @0.neighbors[this] = @1
  @1.neighbors[this] = @0
  @0.srobhgien[@1] = this
  @1.srobhgien[@0] = this

class Player extends Value then (@0, @1) ->
  @id = id++
  @length = 2
  @0.player = this
  @1.player = this

class DisjointSet
  ->
    @parent = this
    @rank = 0
  root: ->
    if @parent is not this
      @parent.=root!
    @parent
  union: !->
    root = @root!
    other = it.root!
    unless root is other
      if root.rank < other.rank
        root.parent = other
      else if root.rank > other.rank
        other.parent = root
      else
        other.parent = root
        root.rank++

# max capacity of connected undirected graph
# based on kruskal max-spanning-tree
# less efficient than linear time algorithms, but also easier to follow
function max-capacity-path topology, weights, [start, end]
  sets = {}
  for vertex in topology.vertices
    sets[vertex] = new DisjointSet

  edges = topology.edges.slice!
    .sort (a, b) -> weights[b] - weights[a] # maximum spanning tree

  tree-edges = {}

  for [u, v]: edge in edges
    us = sets[u]
    vs = sets[v]
    if us.root! is not vs.root!
      tree-edges[edge] = true
      us.union vs

  # dfs on resulting path
  seen = {}

  v-path = [start]
  path = []
  :outer while (vertex = v-path[*-1])
    seen[vertex] = true
    for edge, neighbor of vertex.neighbors
      if tree-edges[edge] and not seen[neighbor]
        v-path.push neighbor
        path.push vertex.srobhgien[neighbor]
        if neighbor is end
          return path
        else
          continue outer
    path.pop!
    v-path.pop!

  throw new Error "no path found somehow!"

# paths are sorted by bandwidth ascending
function observed-available-bandwidth edge, allocs
  residual = edge.bandwidth
  sharing = allocs.length + 1 # plus us
  for alloc in allocs
    fair = residual / sharing
    if alloc <= fair
      residual -= alloc # they're not affected, so we share the rest
      sharing--
    else
      # all remaining players on the edge are using more than will
      # be fair when we are added (allocs sorted), so we will
      # share the residual with them equally
      residual = fair
      break

  return residual

function best-response topology, player, strategy, opponents
  strategies = opponents
    .sort (a, b) -> a.bandwidth - b.bandwidth
  log "#player vs: #{opponents.map (.path)}"

  allocs = {}
  for s in strategies
    for edge in s.path
      allocs[][edge]push s.bandwidth

  available = {}
  for edge in topology.edges
    available[edge] =
      observed-available-bandwidth do
        edge
        allocs[edge] || []
    log "#edge : #{available[edge]} / #{edge.bandwidth}, used by #{allocs[edge]}"

  mcp = max-capacity-path do
    topology, available,
    player

  return
    path: mcp
    bandwidth: d3.min mcp, (available.)

class Strategy then (
  @path # [Edge]
  @bottleneck # Edge
  @bandwidth # Num
) ->

class State extends Value
  (@strategies, @player) ->
    @id = id++

function allocate topology, paths
  residuals = {}
  for edge in topology.edges
    residuals[edge] = edge.bandwidth

  remaining = {[player, true] for player of paths}

  strategies = {}

  while Object.keys(remaining)length > 0
    users = {}
    for player of remaining
      for edge in paths[player]
        users[][edge]push player

    global-bottleneck = min-by topology.edges, (edge) ->
      if residuals[edge] is 0
        Infinity
      else
        residuals[edge] / (users[edge]?length or 0)

    #debugger

    bottlenecked = users[global-bottleneck]

    if not bottlenecked?
      necks = topology.edges.map (edge) ->
        "#{residuals[edge]} #{users[edge]} #{residuals[edge] / (users[edge]?length or 0)}"

      debugger

    alloc = residuals[global-bottleneck] / bottlenecked.length
    log "#global-bottleneck is bottleneck, used by #{bottlenecked} => #alloc"
    for player in bottlenecked
      strategies[player] = new Strategy do
        paths[player]
        global-bottleneck
        alloc
      delete remaining[player]
      for edge in paths[player]
        log "decreasing #edge residual #{residuals[edge]} - #alloc = #{residuals[edge] - alloc}"
        residuals[edge] -= alloc
        residuals[edge] = Math.max 0 residuals[edge]

  return strategies

function min-by arr, view
  min = Infinity
  min-v = void
  for arr
    v = view ..
    if min > v
      min-v = ..
      min = v
  unless min-v?
    ids = arr.map (.id)
    vs = arr.map view
    debugger
  min-v

function maxbargame topology, players, strategies, player
  state = new State strategies, player
  better = false

  strategy = strategies[player]
  br = best-response topology,
    player,
    strategy,
    players.filter (is not player) .map (strategies.)

  log "#player: #{strategy.path} (#{strategy.bandwidth}) => #{br.path} (#{br.bandwidth})"

  next-paths = {}
  for p, strategy of strategies
    next-paths[p] = strategy.path

  if br.bandwidth > strategy.bandwidth
    log "found better!"
    better = true

    next-paths[player] = br.path
  else
    log "no better..."

  next = allocate do
    topology
    next-paths

  return {better, state: new State next}

function connected topology, without
  return false if topology.vertices.length < 1
  seen = {}
  count = 1
  stack = []
  if topology.vertices.0 is not without
    stack.push topology.vertices.0
  else
    stack.push topology.vertices.1

  seen[stack.0] = true
  while stack.length > 0
    v = stack.pop!
    for e, neighbor of v.neighbors
      if not seen[neighbor] and neighbor is not without
        seen[neighbor] = true
        count++
        stack.push neighbor

  if without?
    return count is (topology.vertices.length - 1)
  else
    return count is topology.vertices.length

function rand-int min, max
  Math.random! * (max - min) + min

function random-topology num-players, num-vertices, edge-prob
  #do
  vertices = [new Vertex for i til num-vertices]

  # ring network
  edges = for i til num-vertices
    new Edge vertices[i], vertices[(i+1) % vertices.length], rand-int 3 10

  for i til num-vertices
    for j from i + 2 til num-vertices
      if Math.random! < edge-prob
        edges.push new Edge vertices[i], vertices[j], rand-int 3 10

  weights = {}
  for e in edges
    weights[e] = e.bandwidth

  paths = {}

  #while not connected {edges, vertices}
  players = for i til num-players
    v1 = vertices[r = Math.floor(Math.random! * vertices.length)]
    v2 = vertices[Math.floor(Math.random! * vertices.length)]
    if v2 is v1
      v2 = vertices[(r + 1) % vertices.length]

    p = new Player v1, v2
    paths[p] = max-capacity-path {edges, vertices}, weights, [v1, v2]
    p

  unless connected {edges, vertices}
    throw new Error "not connected"

  return {vertices, edges, players, paths}

