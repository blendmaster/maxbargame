class Node then (@id, @x, @y) ->
  @neighbors = [] # nodes connected to this node
  @edges = [] # edges connecting this node
  @player = void # player who occupies this node with source/sink, or void

class Edge then (@id, @source, @target, @bandwidth) ->
  @source.neighbors.push @target
  @target.neighbors.push @source
  @source.edges.push this
  @target.edges.push this

class Player then (@id, @source, @target) ->
  @source.player = this
  @target.player = this

class PlayerState then (
  @path # [Node]
  @bandwidth # Num, total bandwidth from source-target
  @diff # Num, diff since last known bandwidth
) ->

nodes = (.map ([x, y], i) -> new Node i, x, y) [] =
  * 50 10
  * 45 40
  * 70 30
  * 75 50
  * 90 60
  * 80 90
  * 40 85
  * 30 90
  * 10 50
edges = (.map ([s, t, b], i) -> new Edge i, nodes[s], nodes[t], b) [] =
  * 0 1 10
  * 1 2 5
  * 2 3 8
  * 3 4 5
  * 3 6 10
  * 6 5 9
  * 1 6 4
  * 1 8 10
  * 8 7 6
  * 6 7 5
players = (.map ([s, t], i) -> new Player i, nodes[s], nodes[t]) [] =
  * 0 4
  * 8 3
  * 5 2

game =
  * initialize nodes, edges, players

!function initialize nodes, edges, players
  paths = (.map (.map (edges.))) [] =
    * 0 1 2 3
    * 8 9 4
    * 5 4 2

  final-utilization = []
  utilization = []
  for edge in edges
    utilization.push u = new Set
    final-utilization.push fu = []
    for path, i in paths
      player = players[i]
      for e in path
        if e is edge
          u.add player
          fu.push player

  player-bandwidth = [0 for players]

  undetermined = new Set players
  residuals = edges.map (.bandwidth)

  while undetermined.size > 0
    global-bottleneck = least-equal-share utilization, residuals

    u = utilization[global-bottleneck]
    b = residuals[global-bottleneck]

    fair = b / u.size

    u.for-each !(player) ->
      player-bandwidth[player.id] = fair
      for edge in paths[player.id]
        residuals[edge.id] -= fair
        utilization[edge.id]delete player
      undetermined.delete player

  return
    utilization: final-utilization
    players: players.map (player, i) -> new PlayerState do
      paths[i]
      player-bandwidth[i]
      0 # no diff

function least-equal-share utilization, residuals
  min = void
  min-equality = Infinity
  for i til utilization.length
    u = utilization[i]size
    continue unless u > 0
    b = residuals[i]
    equality = b / u
    if equality < min-equality
      min-equality = equality
      min = i
  return min

x = d3.scale.linear!
  .domain [0 100]
  .range [0 500]

y = d3.scale.linear!
  .domain [0 100]
  .range [0 500]

drag = d3.behavior.drag!
  .on \drag !->
    it.x += x.invert d3.event.dx
    it.y += y.invert d3.event.dy
    draw!

# draw stuff
draw = !->
  d3.select \#edges .select-all \.edge .data edges
    ..enter!append \line .attr \class \edge
    ..attr do
      x1: x << (.source.x)
      y1: y << (.source.y)
      x2: x << (.target.x)
      y2: y <<(.target.y)
      \stroke-width : (.bandwidth) >> (*4)
  d3.select \#nodes .select-all \.node .data nodes
    ..enter!append \circle 
      .attr \class \node
      .call drag
    ..attr do
      cx: x << (.x)
      cy: y << (.y)
      r: -> 2 * d3.max it.edges, (.bandwidth)
  d3.select \#players .select-all \.player .data players
    ..enter!append \g
      ..attr \class \player
      ..attr \id -> "player-#{it.id}"
      ..append \circle .attr \class \source
      ..append \circle .attr \class \target
      ..append \path .attr \class \path
    ..select \.target .attr do
      cx: x << (.target.x)
      cy: y << (.target.y)
      r: -> 10 + 2 * d3.max it.target.edges, (.bandwidth)
    ..select \.source .attr do
      cx: x << (.source.x)
      cy: y << (.source.y)
      r: -> 10 + 2 * d3.max it.source.edges, (.bandwidth)
    ..select \.path
      .attr \d (player) ->
        s = game.players[player.id]

        line = s.path.map ->
          x1 = x it.source.x
          x2 = x it.target.x
          y1 = y it.source.y
          y2 = y it.target.y

          utilization = game.utilization[it.id].slice!

          # adjust to angle of path, so that all allocations on the edge
          # are shown
          offset-start = 0
          for u in utilization
            break if u is player
            offset-start += game.players[u.id]bandwidth

          # since stroke width is from the center, increase offset by half
          # of our bandwidth
          offset-start = offset-start + game.players[player.id]bandwidth / 2

          # offset-start is from top edge of edge's pipe, so y-offset is
          # actually negative for above the center
          offset = offset-start - it.bandwidth / 2

          # offset is a y-offset if our path is horizontal, so rotate
          # according to source/target orientation
          offset *= 4
          angle = Math.atan2 y1 - y2, x2 - x1
          x-offset = offset * Math.sin angle
          y-offset = offset * Math.cos angle

          x1 += x-offset
          x2 += x-offset
          y1 += y-offset
          y2 += y-offset

          #"M #x1 #y1 L #{x1 + x-offset} #{y1 + y-offset} M #{x1 + x-offset} #{y1 + y-offset} L
           ##{x2 + x-offset} #{y2 + y-offset}"
          "M #x1 #y1 L #x2 #y2"
        .join ' '
      .attr \stroke-width ->
        game.players[it.id]bandwidth * 4

  function to-array set
    a = []
    set.for-each !-> a.push it
    return a

draw!
