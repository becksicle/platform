/* //<>//
  Base class for all objects in the game
*/
class Moveable {
  float x, y, vx, vy, w, h;
  float energyLoss = 0.15;
  boolean disableGravity = false;
  boolean isSelected;
  boolean isFinished;
  boolean isEnabled;
  boolean takesInput;

  Moveable(float ix, float iy, float iw, float ih) {
    x = ix;
    y = iy;
    w = iw;
    h = ih;
    isSelected = false;
    isFinished = false;
    isEnabled = true;
    takesInput = false;
  }
  
  // Return true if this moveable can hurt other
  boolean hurts(Moveable other) {
    return false;
  }

  void applyGravity(float gravity) {
    if (disableGravity) return;
    vy += gravity;
  }

  boolean isMoving() {
    return !(within(vx, 0.0, 0.0001) && within(vy, 0.0, 0.0001));
  }

  boolean overlaps(Moveable other) {
    // If one rectangle is on left side of other
    if (x > other.x+other.w || x+w < other.x)
      return false;

    // If one rectangle is above other
    if (y+h < other.y || y > other.y+other.h)
      return false;

    return true;
  }

  boolean wasHorizontalCollision(Moveable other, float vx) {
    // colliding left to right
    if (x+w < other.x && x + w + vx > other.x) return true;
    // colliding right to left
    if (x > other.x+other.w && x + vx < other.x+other.w) return true;
    return false;
  }

  void move(ArrayList<Moveable> others) {  
    float ox = x;
    float oy = y;
    x += vx;
    y += vy;

    for (Moveable other : others) {
      if (other == this || !other.isEnabled) continue;
      
      // if this move causes an ovelap
      if (overlaps(other)) {
        
        // first apply hurting
        if(other.hurts(this)) {
          isFinished = true;
        }
        
        if (hurts(other)) {
          other.isFinished = true;
        }
        
        // then revert to previous location
        x = ox;
        y = oy;

        // transfer velocity to other
        if (!other.disableGravity) {
          other.vx += vx;
          other.vy += vy;
        }

        // bounce
        if (wasHorizontalCollision(other, vx)) {
          vx = -vx*energyLoss;
        } else {
          vy = -vy*energyLoss;
        }

        // don't need tiny velocities
        if (abs(vy) < 0.001) vy = 0.0;
        if (abs(vx) < 0.001) vx = 0.0;
      }
    }
  }

  void draw() {
    if(!isEnabled) return;
    
    if (isSelected) {
      fill(50, 255, 50);
    } else {
      fill(255, 255, 255);
    }
    rect(x, y, w, h);

    text(getClass().getSimpleName(), x+w+5, y);
  }

  // subclasses that can be conrolled by the user should implement
  void applyInputs(Moveable ground, float gravity) {
  }

  // subclasses that are smart/have AI should implement
  Moveable[] applyAI(Moveable ground, float gravity) {
    return null;
  }

  // finds the closest moveable underneath this moveable with horizontal overlap
  Moveable findGround(ArrayList<Moveable> others) {
    Moveable ground = null;
    for (Moveable other : others) {
      if (other == this || !other.isEnabled) continue;
      
      if (other.y >= y+h && 
        ((x >= other.x && x <= other.x+other.w) || 
        (x+w >= other.x && x+w <= other.x+other.w))
        ) {
        if (ground == null || other.y < ground.y) {
          ground = other;
        }
      }
    }
    return ground;
  }

  boolean onGround(Moveable ground) {
    return ground != null && within(y+h, ground.y, 2);
  }
}

class Player extends Moveable {
  float accelerationX = 0.025;
  float maxXVelocity = 0.4;

  Player(float ix, float iy, float iw, float ih) {
    super(ix, iy, iw, ih);
    isSelected = true;
    takesInput = true;
  }

  boolean hurts(Moveable other) {
    return other instanceof Reward;
  }

  void applyInputs(Moveable ground, float gravity) {
    // handle inputs
    boolean onGround = onGround(ground);

    if (keyPressed) {
      if (keyCode == RIGHT) {
        vx = min(vx + accelerationX, maxXVelocity);
      } else if (keyCode == LEFT) {
        vx = max(vx - accelerationX, -maxXVelocity);
      } else if (keyCode == UP) {
        if (onGround) {
          vy = -1.25;
        }
      }
    }
  }
}

class Platform extends Moveable {
  Platform(float ix, float iy, float iw, float ih) {
    super(ix, iy, iw, ih);
    disableGravity = true;
  }
}

class MagicCarpet extends Platform {
  boolean upDown, leftRight;
  
  MagicCarpet(float ix, float iy, float iw, float ih, boolean iupDown, boolean ileftRight) {
    super(ix, iy, iw, ih);
    upDown = iupDown;
    leftRight = ileftRight;
    takesInput = true;
  }

  void applyInputs(Moveable ground, float gravity) {   
    if (keyPressed) {
      if (keyCode == RIGHT && leftRight) {
        vx = 0.5;
      } else if (keyCode == LEFT && leftRight) {
        vx = -0.5;
      } else if (keyCode == UP && upDown) {
        vy = -0.5;
      } else if (keyCode == DOWN && upDown) {
        vy = 0.5;
      }
    } else {
      vx = 0.0;
      vy = 0.0;
    }
  }
}

class Assassin extends Moveable {
  boolean walking;
  boolean shooting;
  int iterationsLeft;
  int walkingIterations = 1 * 60 * 10;
  int shootingIterations = 5 * 60 * 10;
  Moveable target;
  float accelerationX = 0.015;
  float maxXVelocity = 0.25;

  Assassin(Moveable itarget, float ix, float iy, float iw, float ih) {
    super(ix, iy, iw, ih);
    target = itarget;
    walking = true;
    shooting = false;
    iterationsLeft = walkingIterations;
  }

  Moveable[] applyAI(Moveable ground, float gravity) { 
    if(target.isFinished) {
      return null;
    }
    
    iterationsLeft--;
    if (iterationsLeft <= 0) {
      iterationsLeft = (walking) ? shootingIterations : walkingIterations;
      walking = !walking;
      shooting = !shooting;
    }
    
    if (walking) {
      // walk towards target
      boolean goRight = target.x > x;
      boolean jump = target.y < y;
      
      if (goRight) {
        vx = min(vx + accelerationX, maxXVelocity);
      } else {
        vx = max(vx - accelerationX, -maxXVelocity);
      } 
      
      if (jump) {
        if (onGround(ground)) {
          vy = -1.0;
        }
      }
    }

    if (shooting) {
      if((iterationsLeft % 1800) == 0) {
        float tvx = target.x - x;
        float tvy = target.y - y;
        float dist = sqrt(tvx * tvx + tvy*tvy);
        tvx = (tvx / dist);
        tvy = (tvy / dist);
        float lx = (tvx < 0) ? x-w-2 : x+w+2;
        float ly = y - (2+h);
        return new Moveable[] { new Projectile(lx, ly, 8, 8, tvx, tvy)};
      }
    }

    return null;
  }
}

class Projectile extends Moveable {
  Projectile(float ix, float iy, float iw, float ih, float ivx, float ivy) {
    super(ix, iy, iw, ih);
    vx = ivx;
    vy = ivy;
  }
  
  boolean hurts(Moveable other) {
    return other instanceof Player;
  }
  
  Moveable[] applyAI(Moveable ground, float gravity) {
    if(!isMoving()) {
      isFinished = true;
    }
    return null;
  }
}

class Reward extends Moveable {
    Reward(float ix, float iy, float iw, float ih) {
    super(ix, iy, iw, ih);
    disableGravity = true;
  }
}

class OnOffCoordinator {
  ArrayList<OnOffPlatform> platforms;
  int lastChanged;  
  int currentlyOn;
  int changeTime;
  
  OnOffCoordinator() {
    platforms = new ArrayList<OnOffPlatform>();
    lastChanged = millis();
    currentlyOn = 0;
    changeTime = 2000;
  }
  
  boolean isOn(OnOffPlatform m) {
    if((millis() - lastChanged) > changeTime) {
      currentlyOn = (currentlyOn + 1) % platforms.size();
      lastChanged = millis();
      println("Currentlyon: "+currentlyOn);
    }
    int index = find(m);
    if(index == -1) return true;
    return currentlyOn == index || (currentlyOn+1) == index;
  }
  
  int find(OnOffPlatform m) {
     for(int i=0; i < platforms.size(); i++) {
        if(platforms.get(i) == m) return i;
    } 
    return -1;
  }
  
  void add(OnOffPlatform platform) {
    if(find(platform) != -1) return;
    
    platforms.add(platform);
    //platformsOn.add(true);
  }
}

class OnOffPlatform extends Platform {
  OnOffCoordinator coordinator;
  
  OnOffPlatform(float ix, float iy, float iw, float ih, OnOffCoordinator icoordinator) {
    super(ix, iy, iw, ih);
    coordinator = icoordinator;
    coordinator.add(this);
    
  }
  
  Moveable[] applyAI(Moveable ground, float gravity) {
    if(coordinator.isOn(this)) {
      isEnabled = true;
    } else {
      isEnabled = false;
    }
    return null;
  }
}

abstract class Level {
  abstract ArrayList<Moveable> makeMoveables();
}

class Level1 extends Level {
  ArrayList<Moveable> makeMoveables() {
    Player player = new Player(200, 0, 16, 16);
    ArrayList<Moveable> moveables = new ArrayList<Moveable>();
    moveables.add(player);
    moveables.add(new Platform(0, 550, 1000, 10)); // ground
    moveables.add(new Platform(500, 465, 64, 16)); // p1
    moveables.add(new Platform(275, 385, 64, 16)); // p2
    moveables.add(new Platform(0, 0, 15, 600)); // l wall
    moveables.add(new Platform(990, 0, 10, 600)); // r wall
    moveables.add(new MagicCarpet(40, 385, 128, 16, true, false));
    moveables.add(new Assassin(player, 500, 510, 16, 16));
    moveables.add(new Reward(400, 300, 16, 16));
    moveables.add(new Reward(650, 100, 16, 16));
    
    int numOnOffs = 6;
    OnOffCoordinator coordinator = new OnOffCoordinator();
    
    for(int i=0; i < numOnOffs; i++) {
      moveables.add(new OnOffPlatform(200+i*72, 100, 64, 16, coordinator));
    }

    return moveables;
  }
}

class Level2 extends Level {
  ArrayList<Moveable> makeMoveables() {
    Player player = new Player(200, 0, 16, 16);
    
    ArrayList<Moveable> moveables = new ArrayList<Moveable>();
    moveables.add(new Platform(0, 550, 1000, 10)); // ground
    moveables.add(player);
    moveables.add(new Reward(650, 100, 16, 16));
    
    return moveables;
  }
}

class Game {
  Level[] levels = new Level[] { new Level1(), new Level2() };
  int curLevel = 0;
  
  Player player;
  ArrayList<Moveable> moveables;
  ArrayList<Moveable> newMoveables = new ArrayList<Moveable>();
  float gravity = 0.005;
  int steps = 10;
  int selected = 0;

  Game() {
    newLevel(curLevel);
  }
  
  void newLevel(int levelIdx) {
    curLevel = levelIdx;
    Level level = levels[levelIdx];
    moveables = level.makeMoveables();
    for(int i=0; i < moveables.size(); i++) {
      if(moveables.get(i) instanceof Player) {
        player = (Player)moveables.get(i);
        selected = i;
        break;
      }
    }
  }
  
  void draw() {
    background(0);
    stroke(100);
         
    // break each frame into a number of steps to avoid "teleporting" through
    // objects when moving at high velocity
    for (int i=0; i < steps; i++) {
      newMoveables.clear();
      for (Moveable m : moveables) {        
        Moveable mGround = m.findGround(moveables);

        // deal with gravity if the moveable is affected by it
        if (!m.disableGravity) {
          // either fall, apply friction, or move with the moving ground
          if (m.onGround(mGround)) {
            if (mGround.isMoving()) {
              // move with the ground
              m.vx = mGround.vx;
              m.vy = mGround.vy;
            } else { 
              // on ground, but ground is not moving
              // apply slowdown from horizontal friction
              if (m.vx > 0) {
                m.vx = max(0.0, m.vx - 0.005);
              } else if (m.vx < 0) {
                m.vx = min(0.0, m.vx + 0.005);
              }
            }
          } else {
            // not on the ground and therefore,
            // falling
            m.applyGravity(gravity);
          }
        }

        // selected moveables can accept user input
        if (m.isSelected) {
          m.applyInputs(mGround, gravity);
        }
        
        // apply AI and add any new moveables introduced by the AI
        Moveable[] inewMoveables = m.applyAI(mGround, gravity);
        if(inewMoveables != null) {
          for(Moveable imove : inewMoveables) newMoveables.add(imove);
        }
        
        // finally, move the moveable
        m.move(moveables);
      }
      
      // add new moveables from AI to the world
      for(Moveable newMoveable : newMoveables) {
        moveables.add(newMoveable);
      }
        
      // remove finished moveables
      int fi;
      while((fi = findFinished(moveables)) != -1) {
        moveables.remove(fi);
        selected = max(selected-1, 0);
      }
    }

    for (Moveable m : moveables) {
      m.draw();
    }

    Moveable m = moveables.get(selected);
    text("x: " + nfs(m.x, 0, 5) + " y: "+nfs(m.y, 0, 5)+" vx: "+nfs(m.vx, 0, 5)+" vy: "+nfs(m.vy, 0, 4)+ " moving? "+m.isMoving(), 50, 10);
    text("press tab to select other moveable", 50, 20);
    
    // if player fell through the ground or is dead, restart the level
    if (player.y > height || player.isFinished) {
      newLevel(curLevel);
    }
    
    // if no rewards left, the player has defeated the level - move to the next
    if(noRewards()) {
      newLevel((curLevel + 1) % levels.length);
    }
  }
  
  boolean noRewards() {
    for(Moveable m : moveables) {
      if(m instanceof Reward) return false;
    }
    return true;
  }
  
  int findFinished(ArrayList<Moveable> moveables) {
    for(int i=0; i < moveables.size(); i++) {
      if(moveables.get(i).isFinished) return i;
    }
    return -1;
  }

  void keyTyped() {
    if (key == '\t') {
      while(!selectNext().takesInput) {}
    } else if (key == 'q') {
      while(!selectPrev().takesInput) {}
    }
  }
  
  Moveable selectNext() {
    moveables.get(selected).isSelected = false;
    selected = (selected + 1) % moveables.size();
    moveables.get(selected).isSelected = true;
    return moveables.get(selected);
  }
  
  Moveable selectPrev() {
    moveables.get(selected).isSelected = false;
    selected = (selected - 1);
    if (selected < 0) selected = moveables.size()-1;
    moveables.get(selected).isSelected = true;
    return moveables.get(selected);  
  }
}

boolean within(float a, float b, float tol) {
  return abs(a-b) <= tol;
}

float distanceBetween(float x, float y, float ox, float oy) {
  return sqrt((x-ox)*(x-ox) + (y-oy)*(y-oy));
}


////

void setup() {
  size(1000, 600);
  smooth();
  frameRate(60);
}

Game game = new Game();

void draw() {
  game.draw();
}

void keyTyped() {
  game.keyTyped();
}