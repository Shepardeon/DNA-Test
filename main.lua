math.randomseed(os.time())
math.random(); math.random(); math.random()

local WIDTH = love.graphics.getWidth()
local HEIGHT = love.graphics.getHeight()
local MUTATION_RATE = 0.01

local target = {
    x = WIDTH/2,
    y = 40,
    r = 15
}

local gen = 0

local function dist(p1, p2)
    return math.sqrt((p2.x - p1.x)*(p2.x - p1.x) + (p2.y - p1.y)*(p2.y - p1.y))
end

local function createAgent(x, y)

    local width = 10
    local height = 30

    local agent = {}

    agent.pos = {}
    agent.pos.x = x
    agent.pos.y = y

    agent.dir = {}
    agent.dir.x = 0
    agent.dir.y = 0

    agent.ttl = 15
    agent.currGene = 1
    agent.dead = false
    agent.evaluation = -1

    agent.dna = {}

    agent.update = function(dt)
        agent.ttl = agent.ttl - 1*dt
        agent.currGene = agent.currGene + 5*dt
        if agent.ttl > 0 then

            agent.dir.x = agent.dna[math.floor(agent.currGene)].x
            agent.dir.y = agent.dna[math.floor(agent.currGene)].y
            
            ndir = math.sqrt(agent.dir.x * agent.dir.x + agent.dir.y * agent.dir.y)
            dx = agent.dir.x / ndir
            dy = agent.dir.y / ndir

            if dist(agent.pos, target) > 10 then
                agent.pos.x = agent.pos.x + dx
                agent.pos.y = agent.pos.y - dy
            end

            return
        end

        agent.dead = true
    end

    agent.draw = function()
        angle = math.atan(agent.dir.x/agent.dir.y)

        love.graphics.push()
        love.graphics.translate(agent.pos.x, agent.pos.y)
        love.graphics.rotate(angle)
    	love.graphics.rectangle("fill", -width/2, -height/2, width, height) -- origin in the middle
        love.graphics.pop()
    end

    local function newGene()
        local lx, ly

        if math.random() >= 0.5 then
            lx = -math.random()
        else
            lx = math.random()
        end

        if math.random() >= 0.5 then
            ly = -math.random()
        else
            ly = math.random()
        end

        return {
            x = lx,
            y = ly
        }
    end

    agent.initGenome = function()
        -- 1 gene = 1 direction vector
        -- 5 genes change every second
        -- 15s ttl => 75 genes

        for i = 1, 75 do
            gene = newGene()

            table.insert(agent.dna, {
                x = gene.x,
                y = gene.y
            })
        end
    end

    agent.evaluate = function()
        agent.evaluation = dist(agent.pos, target)
    end

    agent.mate = function(other)
        -- merge randomly both parents genes
        -- and apply random mutation to each genes depending on the mutation rate
        offspring = createAgent(WIDTH/2, HEIGHT-40)


        for i = 1, 75 do
            local nextGene

            if math.random() <= MUTATION_RATE then
                nextGene = newGene()
            else
                if math.random() >= 0.5 then
                    nextGene = agent.dna[math.max(1, #offspring.dna)]
                else
                    nextGene = other.dna[math.max(1, #offspring.dna)]
                end
            end

            table.insert(offspring.dna, nextGene)
        end

        return offspring
    end
    
    return agent
end

local agents = {}

function love.load()
    for i = 1, 100 do
        local agent = createAgent(WIDTH/2, HEIGHT-40)
        agent.initGenome()
        table.insert(agents, agent)
    end
end

function love.update(dt)
    for i = 1, #agents do
        local agent = agents[i]

        agent.update(dt)

    end

    if agents[1].dead then
        -- Current generation is dead, time to move to the next one
        -- 1st step: evaluate the best elements => closer to target = better fitted
        for i = 1, #agents do
            agents[i].evaluate()
        end

        -- 2nd step: select the 50 best elements
        table.sort(agents, function(a1, a2) return a1.evaluation < a2.evaluation end)
        mateTable = { unpack(agents, 1, 50) }
        agents = {} -- Clear current table

        -- 3rd step: breed agents that can mate toggether to create the next generation
        -- As we have 50 "survivors", they'll need to make 4 children to get back to a pop
        -- of 100 individuals
        while #mateTable > 0 do
            local p1 = table.remove(mateTable, math.random(#mateTable))
            local p2 = table.remove(mateTable, math.random(#mateTable))

            for i = 1, 4 do
                table.insert(agents, p1.mate(p2))
            end
        end

        gen = gen + 1
    end
end

function love.draw()

    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill", target.x, target.y, target.r)

    love.graphics.setColor(1, 1, 1)
    for i = 1, #agents do
        agent = agents[i]

        if not agent.dead then
            agent.draw()
        end
    end

    love.graphics.print("Gen: "..gen)
    love.graphics.print("Pop Size: "..#agents, 0, 20)
end