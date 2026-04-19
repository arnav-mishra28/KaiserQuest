"""
KaiserQuest Backend v1.0
Multiplayer PvP WebSockets + Voice AI (Whisper STT + gTTS TTS) + Procedural Generation
Run: uvicorn main:app --host 0.0.0.0 --port 8000
"""
import asyncio, json, random, uuid, time, os
from typing import Dict, List, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel

app = FastAPI(title="KaiserQuest API v1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

# ── In-memory state ────────────────────────────────────────────────────────────
active_rooms: Dict[str, dict] = {}
waiting_queue: List[dict] = []   # [{name, ws, world}]

# ── Built-in question bank ─────────────────────────────────────────────────────
QUESTION_BANK = {
    "math:algebra": [
        {"q":"Solve: x+4=9","opts":["x=4","x=5","x=13","x=2"],"ans":1,"topic":"linear"},
        {"q":"If x=3, what is 2x+1?","opts":["5","6","7","8"],"ans":2,"topic":"linear"},
        {"q":"Solve: 3x=15","opts":["x=3","x=5","x=12","x=45"],"ans":1,"topic":"linear"},
        {"q":"Which is a variable?","opts":["7","3.14","y","100"],"ans":2,"topic":"variables"},
        {"q":"If y=2x and x=4, find y","opts":["6","8","10","2"],"ans":1,"topic":"variables"},
        {"q":"Solve: 2x-4=10","opts":["x=3","x=5","x=7","x=14"],"ans":2,"topic":"linear"},
        {"q":"f(x)=x²; f(3)=?","opts":["6","9","12","27"],"ans":1,"topic":"functions"},
        {"q":"Slope of y=3x+2?","opts":["2","3","x","0"],"ans":1,"topic":"linear"},
    ],
    "languages:english": [
        {"q":"What is a NOUN?","opts":["Action","Describing","Person/place/thing","Connecting"],"ans":2,"topic":"nouns"},
        {"q":"Past tense of 'run'?","opts":["runned","ran","runs","running"],"ans":1,"topic":"verbs"},
        {"q":"Comparative of 'big'?","opts":["most big","bigger","biggest","very big"],"ans":1,"topic":"adj"},
        {"q":"'London' is a...?","opts":["Common noun","Proper noun","Abstract","Verb"],"ans":1,"topic":"nouns"},
        {"q":"A VERB is...?","opts":["Describing","Naming","Action/state","Connecting"],"ans":2,"topic":"verbs"},
        {"q":"How many nouns: 'The cat ran'?","opts":["0","1","2","3"],"ans":1,"topic":"nouns"},
        {"q":"Future tense of 'eat'?","opts":["ate","eats","will eat","eating"],"ans":2,"topic":"verbs"},
        {"q":"Superlative of 'fast'?","opts":["faster","fastest","most fast","very fast"],"ans":1,"topic":"adj"},
    ],
    "music:theory": [
        {"q":"Lines on a staff?","opts":["3","4","5","6"],"ans":2,"topic":"staff"},
        {"q":"Whole note beats?","opts":["1","2","3","4"],"ans":3,"topic":"notes"},
        {"q":"Spaces on treble clef spell?","opts":["EGBDF","FACE","ACEG","BDFA"],"ans":1,"topic":"staff"},
        {"q":"Quarter note beats?","opts":["1","2","3","4"],"ans":0,"topic":"notes"},
        {"q":"Major chord sounds?","opts":["Sad","Bright/happy","Tense","Silent"],"ans":1,"topic":"chords"},
        {"q":"4/4 time: beats/measure?","opts":["2","3","4","8"],"ans":2,"topic":"time"},
        {"q":"C-E-G forms a...?","opts":["C minor","G major","C major","A minor"],"ans":2,"topic":"chords"},
        {"q":"Half note beats?","opts":["1","2","3","4"],"ans":1,"topic":"notes"},
    ],
}

def get_questions(world: str, count: int = 7) -> List[dict]:
    pool = QUESTION_BANK.get(world, QUESTION_BANK["math:algebra"]).copy()
    random.shuffle(pool)
    return pool[:min(count, len(pool))]

# ══════════════════════════════════════════════════════════════════════════════
#  PvP MULTIPLAYER WebSocket
# ══════════════════════════════════════════════════════════════════════════════
@app.websocket("/pvp/{player_name}")
async def pvp_websocket(websocket: WebSocket, player_name: str, world: str = "math:algebra"):
    await websocket.accept()
    room_id = None
    try:
        # Try to match with a waiting player
        matched_entry = None
        for entry in list(waiting_queue):
            if entry["world"] == world and entry["name"] != player_name:
                matched_entry = entry; waiting_queue.remove(entry); break

        if matched_entry:
            # Create room
            room_id = str(uuid.uuid4())[:8]
            p1_name, p1_ws = matched_entry["name"], matched_entry["ws"]
            p2_name, p2_ws = player_name, websocket
            questions = get_questions(world)
            room = {
                "id": room_id, "world": world,
                "players": {p1_name: p1_ws, p2_name: p2_ws},
                "scores": {p1_name: 0, p2_name: 0},
                "hp": {p1_name: 30, p2_name: 30},
                "answered": {p1_name: False, p2_name: False},
                "questions": questions, "q_idx": 0,
                "q_start": time.time(), "combos": {p1_name: 0, p2_name: 0},
            }
            active_rooms[room_id] = room
            # Notify both players
            start_msg = json.dumps({"type":"match_found","room":room_id,
                "players":[p1_name,p2_name],"world":world,"total_questions":len(questions)})
            for ws in [p1_ws, p2_ws]:
                try: await ws.send_text(start_msg)
                except: pass
            await asyncio.sleep(0.8)
            await _send_question(room)
        else:
            # Wait for opponent
            waiting_queue.append({"name": player_name, "ws": websocket, "world": world})
            await websocket.send_text(json.dumps({"type":"waiting","msg":"Searching for opponent...","world":world}))

        # Message loop
        while True:
            data = await websocket.receive_text()
            msg  = json.loads(data)
            if msg.get("type") == "answer" and room_id and room_id in active_rooms:
                await _handle_answer(active_rooms[room_id], player_name, int(msg.get("idx",0)))
            elif msg.get("type") == "ping":
                await websocket.send_text(json.dumps({"type":"pong"}))

    except WebSocketDisconnect:
        for entry in list(waiting_queue):
            if entry["name"] == player_name: waiting_queue.remove(entry)
        if room_id and room_id in active_rooms:
            room = active_rooms[room_id]
            for pname, pws in room["players"].items():
                if pname != player_name:
                    try: await pws.send_text(json.dumps({"type":"opponent_left","player":player_name}))
                    except: pass
            del active_rooms[room_id]
    except Exception as e:
        print(f"PvP WS error [{player_name}]: {e}")

async def _send_question(room: dict):
    idx = room["q_idx"]
    if idx >= len(room["questions"]):
        winner = max(room["scores"], key=room["scores"].get)
        msg = json.dumps({"type":"game_over","winner":winner,"scores":room["scores"],"hp":room["hp"]})
        for ws in room["players"].values():
            try: await ws.send_text(msg)
            except: pass
        return
    q = room["questions"][idx]
    room["answered"] = {p: False for p in room["players"]}
    room["q_start"] = time.time()
    msg = json.dumps({"type":"question","idx":idx,"total":len(room["questions"]),
        "q":q["q"],"opts":q["opts"],"topic":q.get("topic","")})
    for ws in room["players"].values():
        try: await ws.send_text(msg)
        except: pass

async def _handle_answer(room: dict, player: str, ans_idx: int):
    if room["answered"].get(player): return
    room["answered"][player] = True
    q = room["questions"][room["q_idx"]]
    elapsed = time.time() - room["q_start"]
    correct = (ans_idx == q["ans"])
    if correct:
        room["combos"][player] = room["combos"].get(player,0) + 1
        speed_mult = max(0.5, 1.5 - elapsed / 10.0)
        combo = min(room["combos"][player], 4)
        damage = int((6 + combo*2) * speed_mult)
        room["scores"][player] = room["scores"].get(player,0) + 100 + int(50*speed_mult)
        opponent = [p for p in room["players"] if p != player]
        if opponent: room["hp"][opponent[0]] = max(0, room["hp"].get(opponent[0],30) - damage)
    else:
        room["combos"][player] = 0
        damage = 0
    result_msg = json.dumps({"type":"answer_result","player":player,"correct":correct,
        "damage":damage,"scores":room["scores"],"hp":room["hp"],"combo":room["combos"][player]})
    for ws in room["players"].values():
        try: await ws.send_text(result_msg)
        except: pass
    # Check HP
    for p,h in room["hp"].items():
        if h <= 0:
            loser = p; winner = [x for x in room["players"] if x!=p][0] if len(room["players"])>1 else p
            end_msg = json.dumps({"type":"game_over","winner":winner,"loser":loser,"scores":room["scores"],"hp":room["hp"]})
            for ws in room["players"].values():
                try: await ws.send_text(end_msg)
                except: pass
            if room["id"] in active_rooms: del active_rooms[room["id"]]
            return
    if all(room["answered"].values()):
        await asyncio.sleep(1.5)
        room["q_idx"] += 1
        await _send_question(room)

@app.get("/pvp/rooms")
async def list_rooms():
    return {"active_rooms": len(active_rooms), "waiting": len(waiting_queue)}

# ══════════════════════════════════════════════════════════════════════════════
#  VOICE AI — Whisper STT + gTTS TTS
# ══════════════════════════════════════════════════════════════════════════════
@app.post("/voice/transcribe")
async def transcribe(audio: UploadFile = File(...)):
    """Speech-to-Text using OpenAI Whisper"""
    try:
        import whisper
        data = await audio.read()
        tmp = f"/tmp/kq_audio_{uuid.uuid4().hex}.wav"
        with open(tmp,"wb") as f: f.write(data)
        model = whisper.load_model("base")   # 'tiny' for faster, 'base' for better accuracy
        result = model.transcribe(tmp)
        os.remove(tmp)
        return {"text": result["text"].strip(), "success": True}
    except ImportError:
        return JSONResponse({"success":False,"error":"Run: pip install openai-whisper"}, status_code=500)
    except Exception as e:
        return JSONResponse({"success":False,"error":str(e)}, status_code=500)

class TTSRequest(BaseModel):
    text: str
    lang: str = "en"

@app.post("/voice/speak")
async def text_to_speech(req: TTSRequest):
    """Text-to-Speech using gTTS"""
    try:
        from gtts import gTTS
        out = f"/tmp/kq_tts_{uuid.uuid4().hex}.mp3"
        gTTS(text=req.text, lang=req.lang, slow=False).save(out)
        return FileResponse(out, media_type="audio/mpeg")
    except ImportError:
        return JSONResponse({"error":"Run: pip install gtts"}, status_code=500)
    except Exception as e:
        return JSONResponse({"error":str(e)}, status_code=500)

class NPCMsg(BaseModel):
    npc_name: str; npc_role: str; message: str; player_level: int; weak_topics: List[str] = []

@app.post("/npc/respond")
async def npc_respond(req: NPCMsg):
    """Rule-based NPC AI (extend with OpenAI/LLM API for smarter responses)"""
    weak_str = ", ".join(req.weak_topics[:2]) if req.weak_topics else "the fundamentals"
    if "teacher" in req.npc_role.lower():
        replies = [
            f"Great question! Focus on {weak_str} to improve faster.",
            f"At Level {req.player_level}, you should be mastering {weak_str}.",
            "Every correct answer pushes the Fog back a little more.",
            f"Your message: '{req.message}' — excellent curiosity! That's how Kaisers are made.",
        ]
    elif "rival" in req.npc_role.lower():
        replies = [
            f"Level {req.player_level}? I'm already ahead. Meet me at the next gym!",
            "Don't think knowledge alone makes you strong. Speed matters too!",
            "I respect your persistence. But I will reach Silver Mountain first.",
        ]
    else:
        replies = [
            "The Fog retreats when knowledge shines!",
            f"Have you mastered {weak_str} yet? The gym awaits!",
            "Silver Mountain looms to the north. Only the worthy may enter.",
        ]
    return {"response": random.choice(replies), "npc": req.npc_name}

# ══════════════════════════════════════════════════════════════════════════════
#  PROCEDURAL WORLD GENERATION — Perlin Noise
# ══════════════════════════════════════════════════════════════════════════════
def _fade(t): return t*t*t*(t*(t*6-15)+10)
def _lerp(a,b,t): return a+t*(b-a)
def _perlin(width, height, scale=8.0, seed=42):
    import math
    random.seed(seed)
    perm = list(range(256)); random.shuffle(perm); perm = perm*2
    def grad(h,x,y):
        h&=3
        if h==0: return x+y
        if h==1: return -x+y
        if h==2: return x-y
        return -x-y
    grid=[]
    for j in range(height):
        row=[]
        for i in range(width):
            x=i/scale; y=j/scale
            xi=int(x)&255; yi=int(y)&255; xf=x-int(x); yf=y-int(y)
            u=_fade(xf); v=_fade(yf)
            aa=perm[perm[xi]+yi]; ab=perm[perm[xi]+yi+1]
            ba=perm[perm[xi+1]+yi]; bb=perm[perm[xi+1]+yi+1]
            val=_lerp(_lerp(grad(aa,xf,yf),grad(ba,xf-1,yf),u),
                      _lerp(grad(ab,xf,yf-1),grad(bb,xf-1,yf-1),u),v)
            row.append((val+1)/2)
        grid.append(row)
    return grid

@app.get("/world/generate")
async def gen_world(width:int=30, height:int=20, seed:int=42, subject:str="math", branch:str="algebra"):
    """Generate procedural tile map using Perlin noise"""
    noise = _perlin(width, height, scale=8.0, seed=seed)
    # Tile thresholds: 0=ocean, 5=path, 1=grass, 2=forest, 3=mountain
    grid=[]
    for j in range(height):
        row=[]
        for i in range(width):
            n=noise[j][i]
            if n<0.22:    row.append(0)   # ocean
            elif n<0.32:  row.append(5)   # beach/path
            elif n<0.60:  row.append(1)   # grass
            elif n<0.76:  row.append(2)   # forest
            else:         row.append(3)   # mountain
        grid.append(row)
    # Topic clustering: place towns in grass regions, gyms nearby
    towns=[]; random.seed(seed+1)
    for _ in range(200):
        tx=random.randint(3,width-4); ty=random.randint(3,height-4)
        if grid[ty][tx]==1 and len(towns)<5:
            far_enough=all(abs(tx-t[0])>5 or abs(ty-t[1])>5 for t in towns)
            if far_enough:
                grid[ty][tx]=7; towns.append((tx,ty))
                if ty>1: grid[ty-1][tx]=8  # gym above town
                if ty>2: grid[ty-2][tx]=5  # path above gym
    # Connect towns with paths
    random.seed(seed+2)
    for j in range(1,height-1):
        for i in range(1,width-1):
            if grid[j][i]==1 and random.random()<0.12:
                grid[j][i]=5
    # Solid borders
    for i in range(width): grid[0][i]=0; grid[height-1][i]=0
    for j in range(height): grid[j][0]=0; grid[j][width-1]=0
    return {"grid":grid,"width":width,"height":height,"subject":subject,"branch":branch,"seed":seed,
            "towns":towns,"tiles":{"0":"ocean","1":"grass","2":"forest","3":"mountain","5":"path","7":"town","8":"gym"}}

# ══════════════════════════════════════════════════════════════════════════════
#  LEADERBOARD
# ══════════════════════════════════════════════════════════════════════════════
_leaderboard: List[dict] = []

@app.post("/leaderboard/submit")
async def submit(data: dict):
    entry={"name":data.get("name","?"),"score":data.get("score",0),
           "subject":data.get("subject",""),"branch":data.get("branch",""),
           "badges":data.get("badges",0),"time":int(time.time())}
    _leaderboard.append(entry)
    _leaderboard.sort(key=lambda x:x["score"],reverse=True)
    return {"rank":_leaderboard.index(entry)+1,"total":len(_leaderboard)}

@app.get("/leaderboard")
async def get_lb(limit:int=10):
    return {"entries":_leaderboard[:limit]}

@app.get("/health")
async def health():
    return {"status":"ok","version":"1.0","rooms":len(active_rooms),"waiting":len(waiting_queue)}
