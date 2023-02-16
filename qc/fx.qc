float FXMA_SPAWNFLAG_STATIC = 1;

float FXMTR_SPAWNFLAG_TELEPORT = 1;

float FXMTR_STATE_SLIDING = 0;
float FXMTR_STATE_TURNING = 1;

void() MoverInitSounds = {
    string stop_snd;
    string move_snd;
    
    switch(self.sounds) {
        case 1: // DOOR Stone
            stop_snd = "doors/drclos4.wav";
            move_snd = "doors/doormv1.wav";
            break;

        case 2: // DOOR Machine
            stop_snd = "doors/hydro2.wav";
            move_snd = "doors/hydro1.wav";
            break;

        case 3: // DOOR Chain
            stop_snd = "doors/stndr2.wav";
            move_snd = "doors/stndr1.wav";
            break;

        case 4: // DOOR Metal
            stop_snd = "doors/ddoor2.wav";
            move_snd = "doors/ddoor1.wav";
            break;

        case 5: // DOOR SEC Medieval
            stop_snd = "doors/latch2.wav";
            move_snd = "doors/winch2.wav";
            break;

        case 6: // DOOR SEC Metal
            stop_snd = "doors/airdoor2.wav";
            move_snd = "doors/airdoor1.wav";
            break;

        case 7: // DOOR SEC Base
            stop_snd = "doors/basesec2.wav";
            move_snd = "doors/basesec1.wav";
            break;

        case 8: // PLAT Base
            stop_snd = "plats/plat2.wav";
            move_snd = "plats/plat1.wav";
            break;

        case 9: // PLAT Chain
            stop_snd = "plats/medplat2.wav";
            move_snd = "plats/medplat1.wav";
            break;

        case 10: // TRAIN Ratchet
            stop_snd = "plats/train2.wav";
            move_snd = "plats/train1.wav";
            break;

        default: // Silent
            stop_snd = "misc/null.wav";
            move_snd = "misc/null.wav";
    }

    if (self.noise1 == "") {
        self.noise1 = stop_snd;
    }

    if (self.noise2 == "") {
        self.noise2 = move_snd;
    }

    precache_sound(self.noise1);
    precache_sound(self.noise2);
};

vector(vector in) normalize_euler_angles;
vector(vector in) normalizeAngles180;

void(string path) SetOrClearModel = {
    if (path) {
        setmodel(self, path);
    } else {
        self.model = string_null;
        self.modelindex = 0;
    }
};

void() FxModelToggleUse = {
    float state;

    /*
    if (self.io_received < 0) {
        state = 0;
    } else if (self.io_received > 0) {
        state = 1;
    } else {
    */
        state = (self.model == self.wad);
    /*
    }
    */

    if (state) {
        SetOrClearModel(self.map);
    } else {
        SetOrClearModel(self.wad);
    }
};

void() fx_model_toggle = {
    FxModelInit();

    if (self.spawnflags & FXMA_SPAWNFLAG_STATIC) {
        makestatic(self);
        return;
    }

    // primary model
    self.wad = self.model;

    if (self.map != "") {
        // secondary model
        precache_model(self.map);
    } else {
        self.map = string_null;
    }

    self.use = FxModelToggleUse;
};

void() FxModelInit = {
    self.solid = SOLID_NOT;

    if (self.avelocity != '0 0 0') {
        self.movetype = MOVETYPE_NOCLIP;
    } else {
        self.movetype = MOVETYPE_NONE;
    }

    if (self.model != "") {
        precache_model(self.model);
        setmodel(self, self.model);
    } else {
        self.model = string_null;
    }
};

void() FxModelTrainTranslate;
vector(entity corner) FxModelTrainGetDeltaAngles;

void() FxModelTrainStop = {
    self.use = FxModelTrainTranslate;
    sound(self, CHAN_VOICE, self.noise1, 1, ATTN_NORM);
};

void() FxModelTrainTurn = {
    entity t;
    vector delta_angles;
    float turn_time;
    void() next_action;

    // Keep angles within reasonable limits, for precision's sake
    self.angles = normalize_euler_angles(self.angles);

    // We just finished moving to target, so we know it *should* exist
    // (unless killtargeted, ofc)
    t = find(world, targetname, self.target);
    turn_time = fabs(t.wait);
    delta_angles = FxModelTrainGetDeltaAngles(t);

    if (delta_angles == '0 0 0') {
        if (t.wait == 0) {
            FxModelTrainTranslate();
        } else {
            FxModelTrainStop();

            if (t.wait > 0) {
                self.nextthink = time + turn_time;
                self.think = FxModelTrainTranslate;
            }
        }
    } else {
        if (turn_time == 0) {
            self.angles+= delta_angles;
            FxModelTrainStop();
        } else {
            if (t.wait > 0) {
                next_action = FxModelTrainTranslate;
            } else {
                next_action = FxModelTrainStop;
            }

            SUB_CalcAngleMove(
                    self.angles + delta_angles,
                    vlen(delta_angles) / turn_time,
                    next_action);
            sound(self, CHAN_VOICE, self.noise3, 1, ATTN_NORM);
        }
    }

    self.target = t.target;
};

void() FxModelTrainTranslate = {
    entity t;

    // There may not be a next corner, so check that it exists
    if (self.target) {
        t = find(world, targetname, self.target);

        if (t) {
            // "Lock" train until it stops
            self.use = SUB_Null;

            SUB_CalcMove(t.origin, self.speed, FxModelTrainTurn);
            sound(self, CHAN_VOICE, self.noise2, 1, ATTN_NORM);
            return;
        }
    }

    FxModelTrainStop();
};

vector(entity corner) FxModelTrainGetDeltaAngles = {
    entity next;
    vector turn_to;

    if (corner.target) {
        next = find(world, targetname, corner.target);

        if (next) {
            turn_to = vectoangles(next.origin - corner.origin) + self.mangle;
            turn_to = normalize_euler_angles(turn_to);
            
            // minimize wobble going into vertical
            if (turn_to_x == 90 || turn_to_x == -90) {
                turn_to_y = self.angles_y;
            }

            turn_to_z = self.angles_z;

            // rotate MINIMUM distance
            return normalizeAngles180(turn_to - self.angles);
        }
    }

    return '0 0 0';
};

void() FxModelTrainInit = {
    entity t;

    if (self.target) {
        t = find(world, targetname, self.target);

        if (t) {
            if (self.spawnflags & FXMTR_SPAWNFLAG_TELEPORT) {
                self.target = t.target;
                setorigin(self, t.origin);
                self.angles+= FxModelTrainGetDeltaAngles(t);
            } else {
                self.angles+= FxModelTrainGetDeltaAngles(self);
            }
        }
    }

    if (self.targetname == "" || !self.targetname) {
        FxModelTrainTranslate();
    }
};

void() fx_model_train = {
    FxModelInit();
    MoverInitSounds();

    // angular offset
    self.mangle = self.angles;
    
    if (self.noise3 != "") {
        precache_sound(self.noise3);
    } else {
        self.noise3 = self.noise2;
    }

    self.movetype = MOVETYPE_NOCLIP;

    if (!self.speed) {
        self.speed = 100;
    } else {
        self.speed = fabs(self.speed);
    }

    self.nextthink = time + 0.01;
    self.think = FxModelTrainInit;
    self.use = FxModelTrainTranslate;
};
