id = 0

log = -> # NOP
# log = console.log

class Value then to-string: -> @id

class Vertex extends Value then () ->
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

class State
  (@strategies, @turn) ->

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
      residuals[edge] / (users[edge]?length or 0)

    bottlenecked = users[global-bottleneck]

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

  return strategies

function min-by arr, view
  min = Infinity
  min-v = void
  for arr
    v = view ..
    if min > v
      min-v = ..
      min = v
  min-v

function maxbargame topology, players, strategies
  states = [new State strategies]
  iterations = 0
  do
    equilibrium = true

    for player in players
      strategy = strategies[player]
      br = best-response topology,
        player,
        strategy,
        players.filter (is not player) .map (strategies.)

      log "#player: #{strategy.path} (#{strategy.bandwidth}) => #{br.path} (#{br.bandwidth})"

      if br.bandwidth > strategy.bandwidth
        log "found better!"
        equilibrium = false

        next-paths = {}
        for p, strategy of strategies
          next-paths[p] = strategy.path
        next-paths[player] = br.path

        next = allocate do
          topology
          next-paths

        log next
      else
        log "no better..."

      states.push new State next, player
      strategies = next

    iterations++
  while not equilibrium and iterations < 10

  return states

