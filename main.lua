math.randomseed(os.time())
math.random(); math.random(); math.random()

local WIDTH = love.graphics.getWidth()
local HEIGHT = love.graphics.getHeight()
local MUTATION_RATE = 0.01
local POP_SIZE = 200

local chrono = 20

local target = {
    x = WIDTH/2,
    y = 40,
    r = 15
}

local obstacle = {
    x = WIDTH/2,
    y = HEIGHT/2 + 25,
    w = 250,
    h = 10
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

    agent.dist = dist(agent.pos, target)

    agent.dir = {}
    agent.dir.x = 0
    agent.dir.y = 0

    agent.ttl = 20
    agent.currGene = 1
    agent.dead = false
    agent.reachedGoal = false
    agent.evaluation = -1

    agent.dna = {}

    agent.update = function(dt)
        local d = dist(agent.pos, target)

        if not agent.dead and not agent.reachedGoal then
            agent.ttl = agent.ttl - 1*dt
            agent.currGene = agent.currGene + 5*dt
            if agent.ttl > 0 then

                agent.dir.x = agent.dna[math.floor(agent.currGene)].x
                agent.dir.y = agent.dna[math.floor(agent.currGene)].y
                
                ndir = math.sqrt(agent.dir.x * agent.dir.x + agent.dir.y * agent.dir.y)
                dx = agent.dir.x / ndir
                dy = agent.dir.y / ndir

                if d < agent.dist then
                    agent.dist = d
                end

                if d > 10 then
                    agent.pos.x = agent.pos.x + dx
                    agent.pos.y = agent.pos.y - dy

                    -- Check collision with obstacle
                    if  agent.pos.x > obstacle.x - obstacle.w/2 and
                        agent.pos.x < obstacle.x + obstacle.w/2 and
                        agent.pos.y > obstacle.y - obstacle.h/2 and
                        agent.pos.y < obstacle.y + obstacle.h/2 then
                    
                        agent.dead = true

                    end
                else
                    agent.reachedGoal = true
                end

                return
            end

            agent.dead = true
            agent.ttl  = 0
        end
    end

    agent.draw = function()
        angle = math.atan(agent.dir.x/agent.dir.y)

        love.graphics.push()
        love.graphics.translate(agent.pos.x, agent.pos.y)
        if not agent.dead and not agent.reachedGoal then
            love.graphics.rotate(angle)
        end
    	love.graphics.rectangle("fill", -width/2, -height/2, width, height) -- origin in the middle
        love.graphics.pop()
    end

    local function newGene()
        local lx, ly

        lx = math.random() * 2 - 1
        ly = math.random() * 2 - 1

        return {
            x = lx,
            y = ly
        }
    end

    agent.initGenome = function()
        -- 1 gene = 1 direction vector
        -- 5 genes change every second
        -- 20s ttl => 100 genes

        for i = 1, 100 do
            gene = newGene()

            table.insert(agent.dna, {
                x = gene.x,
                y = gene.y
            })
        end
    end

    agent.evaluate = function()

        if agent.dead then
            -- If we died prematurely we are unfit
            agent.evaluation = 0

            -- If we died of old age, our fitness depends on how close we
            -- were able to get from the target
            if agent.ttl == 0 then
                agent.evaluation = 1/agent.dist

                -- If we were able to move past the obstacle, we are better fit
                if agent.pos.y < obstacle.y + obstacle.h/2 then
                    agent.evaluation = agent.evaluation + 0.005
                end
            end

        elseif agent.reachedGoal then
            -- If we reached the goal, the faster we did, the better
            agent.evaluation = 1/agent.dist + agent.ttl
        end

    end

    agent.mate = function(other)
        -- merge randomly both parents genes
        -- and apply random mutation to each genes depending on the mutation rate
        offspring = createAgent(WIDTH/2, HEIGHT-40)


        for i = 1, 100 do
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
    for i = 1, POP_SIZE do
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

    if chrono <= 0 then
        -- Current generation is dead, time to move to the next one
        -- 1st step: evaluate the best elements => closer to target = better fitted
        for i = 1, #agents do
            agents[i].evaluate()
        end

        -- 2nd step: determine for each agent their %age of fitness
        -- and map them to a range between 0 and 1 depending on how likely
        -- they are to reproduce
        local gFitness = 0
        for i = 1, #agents do
            gFitness = gFitness + agents[i].evaluation
        end

        print("Gen "..gen.." fitness: "..gFitness/#agents)

        table.sort(agents, function(a1, a2) return a1.evaluation > a2.evaluation end)

        local cum = 0
        for i = 1, #agents do
            agents[i].evaluation = agents[i].evaluation / gFitness
            cum = cum + agents[i].evaluation
            agents[i].cum = cum
        end


        -- 3rd step: create a mate table and make a new population with it
        mateTable = { unpack(agents) }
        agents = {} -- Clear current table

        while #agents < POP_SIZE do
            -- Select parent 1
            local n1 = math.random()

            local p1, p2
            for i = 1, #mateTable do
                if n1 <= mateTable[i].cum then
                    p1 = mateTable[i]
                    break
                end
            end

            -- Select parent 2 and make sure it's different from parent 2
            repeat
                local n2 = math.random()
                for i = 1, #mateTable do
                    if n2 <= mateTable[i].cum then
                        p2 = mateTable[i]
                        break
                    end
                end
            until p1 ~= p2

            -- Create an offspring and insert it into the population table
            table.insert(agents, p1.mate(p2))

        end

        gen = gen + 1
        chrono = 20
    end

    chrono = chrono - 1 * dt
end

function love.draw()

    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill", target.x, target.y, target.r)

    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", obstacle.x-obstacle.w/2, obstacle.y-obstacle.h/2, obstacle.w, obstacle.h)

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