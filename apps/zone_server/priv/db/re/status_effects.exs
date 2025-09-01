%{
  # Stone/Petrification - Progressive effect with two phases
  sc_stone: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    phases: %{
      wait: %{
        duration: 5000,
        modifiers: %{
          mdef: 25,
          movement_speed: -50
        },
        next: :stone
      },
      stone: %{
        modifiers: %{
          element: :earth1,
          def: -50,
          mdef: 25
        },
        flags: [:no_move, :no_attack, :no_skill, :no_magic],
        on_damage: [
          %{
            type: :conditional,
            condition: "element == :earth",
            then_actions: [
              %{type: :remove_status, status: :sc_stone}
            ]
          }
        ]
      }
    },
    calc_flags: [:def_ele, :def, :mdef, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Freeze - Frozen state with defense penalties
  sc_freeze: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    modifiers: %{
      # Water element level 1 (should be :water1 not numeric 10)
      def_ele: :water1,
      # -50% physical defense (rAthena: def /= 2)
      def_rate: -50,
      # +25% magic defense (rAthena: mdef += 25 * mdef / 100)
      mdef_rate: 25
    },
    flags: [:no_move, :no_attack, :no_skill],
    on_apply: [
      %{type: :remove_status, status: :sc_aeterna},
      # Check for undead immunity
      %{
        type: :conditional,
        condition: "race == :undead",
        then_actions: [
          %{type: :remove_status, status: :sc_freeze}
        ]
      }
    ],
    calc_flags: [:def_ele, :def_rate, :mdef_rate],
    conflicts_with: [:sc_aeterna],
    prevented_by: [
      :sc_refresh,
      :sc_inspiration,
      :sc_warmer,
      :sc_freeze,
      :sc_burning,
      :sc_protection
    ],
    immunity: [:undead]
  },

  # Stun - Complete action prevention
  sc_stun: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Sleep - Character is asleep, removed on damage
  sc_sleep: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    on_damage: [
      %{type: :remove_status, status: :sc_sleep}
    ],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_sleep, :sc_protection]
  },

  # Poison - DoT with defense reduction
  sc_poison: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      def2: -25
    },
    tick: %{
      interval: 1000,
      actions: [
        %{
          type: :damage,
          # rAthena formula: Players: 2 + max_hp * 3 / 200, Monsters: 2 + max_hp / 200
          formula: "is_player and (2 + max_hp * 3 / 200) or (2 + max_hp / 200)",
          element: :neutral,
          min: 1,
          ignore_def: true
        }
      ]
    },
    on_apply: [
      %{type: :remove_status, status: :sc_concentrate},
      %{type: :remove_status, status: :sc_truesight},
      %{type: :notify_client, packet: :sc_poison_icon}
    ],
    calc_flags: [:def],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon]
  },

  # Curse - LUK reduction and ATK penalty
  sc_curse: %{
    properties: [:debuff],
    modifiers: %{
      # Set LUK to 0 (rAthena: set to 0, not -999)
      luk: 0,
      # -25% total ATK (combined base + weapon)
      atk_rate: -25,
      movement_speed: -10
    },
    on_apply: [
      # Check for LUK-based immunity (rAthena: immune if LUK is already 0)
      %{
        type: :conditional,
        condition: "luk == 0",
        then_actions: [
          %{type: :remove_status, status: :sc_curse}
        ]
      }
    ],
    calc_flags: [:luk, :atk, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_curse, :sc_protection]
  },

  # Silence - Prevents casting
  sc_silence: %{
    properties: [:debuff, :prevents_skills],
    flags: [:no_magic],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Confusion - Random movement
  sc_confusion: %{
    properties: [:debuff],
    flags: [:confused_movement],
    on_apply: [
      %{type: :notify_client, packet: :sc_confusion_icon}
    ],
    calc_flags: [],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Blind - HIT and FLEE reduction
  sc_blind: %{
    properties: [:debuff],
    modifiers: %{
      hit: -25,
      flee: -25
    },
    calc_flags: [:hit, :flee],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Bleeding - DoT with SP drain
  sc_bleeding: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      # No HP regeneration
      hp_regen: -100,
      # No SP regeneration
      sp_regen: -100
    },
    tick: %{
      interval: 10000,
      actions: [
        %{
          type: :damage,
          formula: "200 + val1 * 10",
          element: :neutral,
          min: 1
        },
        %{
          type: :damage,
          formula: "val1 * 2",
          min: 1
        }
      ]
    },
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Arcane Charge - Buff with charge accumulation and explosion
  sc_arcane_charge: %{
    properties: [:buff],
    instance_state: %{charges: 0},
    modifiers: %{
      matk: "state.charges * 10"
    },
    on_damaged: [
      %{type: :increment_state, key: :charges},
      %{type: :notify_client, packet: :update_charges, data: %{charges: "state.charges"}},
      %{
        type: :conditional,
        condition: "state.charges >= 3",
        then_actions: [
          %{type: :damage, formula: "caster.int * 2", element: :neutral},
          %{type: :set_state, key: :charges, value: 0},
          %{type: :notify_client, packet: :arcane_explosion}
        ]
      }
    ],
    calc_flags: [:matk]
  },

  # Deadly Poison - DoT with high damage and no HP regeneration
  sc_dpoison: %{
    properties: [:debuff, :damage_over_time],
    modifiers: %{
      # No HP regeneration
      hp_regen: -100,
      # No SP regeneration
      sp_regen: -100,
      # -25% defense reduction
      def_rate: -25
    },
    tick: %{
      interval: 1000,
      actions: [
        %{
          type: :conditional,
          # rAthena: HP must be > max(max_hp/4, damage)
          # Damage formula - Players: 2 + max_hp / 50, Monsters: 2 + max_hp / 100
          condition:
            "hp > max(max_hp / 4, is_player and (2 + max_hp / 50) or (2 + max_hp / 100))",
          then_actions: [
            %{
              type: :damage,
              # rAthena formula - Players: 2 + max_hp / 50, Monsters: 2 + max_hp / 100
              formula: "is_player and (2 + max_hp / 50) or (2 + max_hp / 100)",
              element: :neutral,
              min: 1,
              ignore_def: true
            }
          ]
        }
      ]
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_dpoison_icon}
    ],
    calc_flags: [:def, :regen],
    immunity: [:boss, :plant],
    cleanse: [:sc_slowpoison, :sc_poisoningweapon],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Provoke - ATK/DEF modifier with aggro
  sc_provoke: %{
    properties: [:debuff],
    modifiers: %{
      # ATK increase percentage (rAthena: unified ATK modifier)
      atk_rate: "val2",
      # DEF reduction percentage  
      def_rate: "-val3",
      # VIT DEF reduction
      def2_rate: "-val3",
      # HIT bonus
      hit: "val3"
    },
    on_apply: [
      %{type: :set_state, key: :provoked_by, value: "caster.id"},
      %{type: :notify_client, packet: :sc_provoke_icon}
    ],
    on_remove: [
      %{type: :set_state, key: :provoked_by, value: nil}
    ],
    calc_flags: [:atk, :def, :def2, :hit],
    end_on_start: [:sc_freeze, :sc_stone, :sc_sleep, :sc_trickdead],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Endure - Hit count based defense with MDEF bonus  
  sc_endure: %{
    properties: [:buff],
    instance_state: %{hits_remaining: 7},
    modifiers: %{
      # MDEF bonus based on skill level
      mdef: "val1",
      # Prevents being knocked back/stunned
      endure: true
    },
    on_damaged: [
      %{
        type: :conditional,
        # val4 = infinite endure flag
        condition: "state.hits_remaining > 0 and not val4",
        then_actions: [
          %{type: :increment_state, key: :hits_remaining, amount: -1},
          %{
            type: :conditional,
            condition: "state.hits_remaining <= 0",
            then_actions: [
              %{type: :remove_status, status: :sc_endure}
            ]
          }
        ]
      }
    ],
    calc_flags: [:mdef],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Two-Hand Quicken - ASPD and critical bonus
  sc_twohandquicken: %{
    properties: [:buff],
    modifiers: %{
      # Fixed ASPD bonus
      aspd: "val2",
      # HIT bonus
      hit: "val1 * 2",
      # Critical bonus
      cri: "(2 + val1) * 10"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_twohandquicken_icon}
    ],
    flags: [:require_weapon],
    calc_flags: [:aspd, :hit, :cri],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Concentrate - AGI/DEX boost with defense reduction
  sc_concentrate: %{
    properties: [:buff],
    modifiers: %{
      # AGI increase based on skill level
      agi: "(agi - val3) * val2 / 100",
      # DEX increase based on skill level  
      dex: "(dex - val4) * val2 / 100"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_concentrate_icon},
      %{type: :remove_status, status: :sc_poison},
      %{type: :remove_status, status: :sc_truesight}
    ],
    calc_flags: [:agi, :dex],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Hiding - Complete invisibility with movement restrictions
  sc_hiding: %{
    properties: [:buff],
    modifiers: %{
      movement_speed:
        "(pc_checkskill(target, rg_tunneldrive) > 0) * (-(120 - 6 * pc_checkskill(target, rg_tunneldrive)))"
    },
    flags: [:hide, :no_pick_item, :no_consume_item, :stop_attacking],
    # Can't move unless Tunnel Drive
    states: [:nomovecond],
    on_apply: [
      %{type: :notify_client, packet: :sc_hiding_icon},
      %{type: :set_state, key: :hidden, value: true}
    ],
    on_remove: [
      %{type: :set_state, key: :hidden, value: false}
    ],
    on_move: [
      %{type: :remove_status, status: :sc_hiding}
    ],
    on_damaged: [
      %{type: :remove_status, status: :sc_hiding}
    ],
    calc_flags: [:speed],
    end_on_start: [:sc_closeconfine, :sc_closeconfine2],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Cloaking - Conditional invisibility with wall requirements
  sc_cloaking: %{
    properties: [:buff],
    modifiers: %{
      # Double critical rate
      cri: "cri",
      # Simplified formula without wall check
      movement_speed:
        "(val1 >= 10) * (-25) + (val1 < 10 and val1 >= 3) * (-(30 - 3 * val1)) + (val1 < 3) * (-300)"
    },
    flags: [:cloak, :no_pick_item, :stop_attacking],
    on_apply: [
      %{type: :notify_client, packet: :sc_cloaking_icon},
      %{type: :set_state, key: :cloaked, value: true}
    ],
    on_remove: [
      %{type: :set_state, key: :cloaked, value: false}
    ],
    on_move: [
      %{
        type: :conditional,
        # Always false - needs proper implementation
        condition: "0",
        then_actions: [
          %{type: :remove_status, status: :sc_cloaking}
        ]
      }
    ],
    on_damaged: [
      %{type: :remove_status, status: :sc_cloaking}
    ],
    calc_flags: [:cri, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Enchant Poison - Weapon element change with poison chance
  sc_encpoison: %{
    properties: [:buff],
    modifiers: %{
      atk_ele: :poison
    },
    # Poison chance in 1/10000 rate
    instance_state: %{poison_chance: "250 + 50 * val1"},
    on_attack: [
      %{
        type: :conditional,
        condition: "rand() < state.poison_chance",
        then_actions: [
          %{
            type: :apply_status,
            status: :sc_poison,
            duration: "skill_get_time2(:as_enchantpoison, val1)"
          }
        ]
      }
    ],
    on_apply: [
      %{type: :notify_client, packet: :sc_encpoison_icon}
    ],
    calc_flags: [:atk_ele],
    end_on_start: [
      :sc_aspersio,
      :sc_fireweapon,
      :sc_waterweapon,
      :sc_windweapon,
      :sc_earthweapon,
      :sc_shadowweapon,
      :sc_ghostweapon
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Poison React - Damage boost and counter-attack on poison damage
  sc_poisonreact: %{
    properties: [:buff],
    instance_state: %{counter_remaining: "val1 / 2", boost_mode: false},
    on_damaged: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true},
          %{type: :increment_state, key: :counter_remaining, amount: -1},
          %{
            type: :conditional,
            condition: "state.counter_remaining <= 0",
            then_actions: [
              %{type: :remove_status, status: :sc_poisonreact}
            ]
          }
        ]
      }
    ],
    on_attack: [
      %{
        type: :conditional,
        condition: "state.boost_mode",
        then_actions: [
          %{
            type: :modify_stat,
            stat: :atk_rate,
            amount: "30 * pc_checkskill(caster, :as_poisonreact)"
          },
          %{type: :set_state, key: :boost_mode, value: false},
          %{
            type: :apply_status,
            status: :sc_poison,
            chance: 50,
            duration: "skill_get_time2(:as_poisonreact, val1)"
          },
          %{type: :remove_status, status: :sc_poisonreact}
        ]
      }
    ],
    calc_flags: [:atk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Quagmire - AGI/DEX reduction and removes speed buffs
  sc_quagmire: %{
    properties: [:debuff],
    modifiers: %{
      agi: "-val2",
      dex: "-val2",
      # ASPD penalty
      aspd: "val2",
      # Movement speed penalty
      movement_speed: 50
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_quagmire_icon},
      %{type: :remove_status, status: :sc_loud},
      %{type: :remove_status, status: :sc_concentrate},
      %{type: :remove_status, status: :sc_truesight},
      %{type: :remove_status, status: :sc_windwalk},
      %{type: :remove_status, status: :sc_magneticfield},
      %{type: :remove_status, status: :sc_cartboost},
      %{type: :remove_status, status: :sc_gn_cartboost},
      %{type: :remove_status, status: :sc_increaseagi},
      %{type: :remove_status, status: :sc_adrenaline},
      %{type: :remove_status, status: :sc_adrenaline2},
      %{type: :remove_status, status: :sc_spearquicken},
      %{type: :remove_status, status: :sc_twohandquicken},
      %{type: :remove_status, status: :sc_onehand},
      %{type: :remove_status, status: :sc_merc_quicken},
      %{type: :remove_status, status: :sc_acceleration}
    ],
    calc_flags: [:agi, :dex, :aspd, :speed],
    conflicts_with: [:sc_speedup1],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Angelus - DEF2 increase with visual effect
  sc_angelus: %{
    properties: [:buff],
    modifiers: %{
      # VIT-based defense increase
      def2_rate: "val2",
      # Small MaxHP increase
      maxhp_rate: 5
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_angelus_icon},
      %{type: :set_visual_effect, effect: :angelus_aura}
    ],
    calc_flags: [:def2, :maxhp],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Blessing - STR/INT/DEX increase, cures curse/stone
  sc_blessing: %{
    properties: [:buff],
    modifiers: %{
      # rAthena logic: val2 is set to 0 for undead/demon, causing stat reduction
      # For undead/demon: str -= str/2 (when val2=0)
      # For others: str += val2 (normal blessing bonus)
      str: "val2 + (val2 == 0) * (-str / 2)",
      int: "val2 + (val2 == 0) * (-int / 2)",
      dex: "val2 + (val2 == 0) * (-dex / 2)",
      # HIT bonus follows same pattern
      hit: "val2 * 3 + (val2 == 0) * (-hit / 2)"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_blessing_icon},
      # Check and handle curse first
      %{
        type: :conditional,
        condition: "has_status(:sc_curse)",
        then_actions: [
          %{type: :remove_status, status: :sc_curse},
          # Mark that blessing should not provide stat boost if curse was present
          %{type: :set_state, key: :curse_removed, value: true}
        ]
      },
      # Remove stone only if curse was not present
      %{
        type: :conditional,
        condition: "has_status(:sc_stone) and not state.curse_removed",
        then_actions: [
          %{type: :remove_status, status: :sc_stone}
        ]
      },
      # If curse was removed, prevent stat boost
      %{
        type: :conditional,
        condition: "state.curse_removed",
        then_actions: [
          %{type: :remove_status, status: :sc_blessing}
        ]
      }
    ],
    calc_flags: [:str, :int, :dex, :hit],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Signum Crucis - DEF reduction debuff
  sc_signumcrucis: %{
    properties: [:debuff],
    modifiers: %{
      # Physical defense reduction
      def_rate: "-val2"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_signumcrucis_icon}
    ],
    calc_flags: [:def],
    conflicts_with: [:sc_signumcrucis],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Increase AGI - AGI/ASPD/Speed boost
  sc_increaseagi: %{
    properties: [:buff],
    modifiers: %{
      # AGI increase: use val2 (which equals 2 + val1)
      agi: "val2",
      # Movement speed increase (negative = faster)
      movement_speed: "-(val1 + 1) * 25 / 4",
      # ASPD increase
      aspd: "val1"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_increaseagi_icon},
      %{type: :remove_status, status: :sc_decreaseagi},
      %{type: :remove_status, status: :sc_adoramus}
    ],
    calc_flags: [:agi, :speed, :aspd],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Decrease AGI - AGI/Speed reduction
  sc_decreaseagi: %{
    properties: [:debuff],
    modifiers: %{
      # AGI reduction: -(2 + skill_level)
      agi: "-(2 + val1)",
      # Movement speed reduction
      movement_speed: "(val1 + 1) * 25 / 4"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_decreaseagi_icon},
      %{type: :remove_status, status: :sc_cartboost},
      %{type: :remove_status, status: :sc_gn_cartboost},
      %{type: :remove_status, status: :sc_increaseagi},
      %{type: :remove_status, status: :sc_adrenaline},
      %{type: :remove_status, status: :sc_adrenaline2},
      %{type: :remove_status, status: :sc_spearquicken},
      %{type: :remove_status, status: :sc_twohandquicken},
      %{type: :remove_status, status: :sc_onehand},
      %{type: :remove_status, status: :sc_merc_quicken},
      %{type: :remove_status, status: :sc_acceleration}
    ],
    calc_flags: [:agi, :speed],
    conflicts_with: [:sc_speedup1],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Slow Poison - Slows poison damage and improves regeneration
  sc_slowpoison: %{
    properties: [:buff],
    modifiers: %{
      # Enhanced HP regeneration
      hp_regen: 100
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_slowpoison_icon}
    ],
    # Blocks dispel effects on poison
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Impositio Manus - Weapon/Magic attack increase
  sc_impositio: %{
    properties: [:buff],
    modifiers: %{
      # Weapon attack increase: 5 * skill_level
      watk: "val2",
      # Magic attack increase: 5 * skill_level  
      matk: "val2"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_impositio_icon},
      # Remove existing impositio to refresh
      %{type: :remove_status, status: :sc_impositio}
    ],
    calc_flags: [:watk, :matk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Suffragium - Reduces casting time
  sc_suffragium: %{
    properties: [:buff],
    instance_state: %{cast_time_reduction: "val1 * 15"},
    on_apply: [
      %{type: :notify_client, packet: :sc_suffragium_icon}
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Aspersio - Holy weapon enchantment
  sc_aspersio: %{
    properties: [:buff],
    modifiers: %{
      atk_ele: :holy
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_aspersio_icon},
      %{type: :remove_status, status: :sc_encpoison},
      %{type: :remove_status, status: :sc_fireweapon},
      %{type: :remove_status, status: :sc_waterweapon},
      %{type: :remove_status, status: :sc_windweapon},
      %{type: :remove_status, status: :sc_earthweapon},
      %{type: :remove_status, status: :sc_shadowweapon},
      %{type: :remove_status, status: :sc_ghostweapon},
      %{type: :remove_status, status: :sc_enchantarms}
    ],
    calc_flags: [:atk_ele],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Benedictio Sanctissimi Sacramenti - Armor element change to holy
  sc_benedictio: %{
    properties: [:buff],
    modifiers: %{
      def_ele: :holy1
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_benedictio_icon}
    ],
    calc_flags: [:def_ele],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Kyrie Eleison - Damage absorption shield
  sc_kyrie: %{
    properties: [:buff],
    instance_state: %{
      # Hits remaining counter
      hits_remaining: "val3",
      # Damage absorption amount
      shield_hp: "val2"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_kyrie_icon},
      %{type: :set_visual_effect, effect: :kyrie_shield}
    ],
    on_damaged: [
      %{
        type: :conditional,
        condition:
          "state.shield_hp > 0 and (dmg_type == :physical or skill_id == :tf_throwstone)",
        then_actions: [
          # Reduce shield HP by damage amount
          %{type: :set_state, key: :shield_hp, value: "-damage"},
          # Reduce hits counter
          %{type: :set_state, key: :hits_remaining, value: "-1"},
          # Completely block damage if shield has HP left
          %{
            type: :conditional,
            condition: "state.shield_hp >= 0",
            then_actions: [
              %{type: :set_damage, amount: 0}
            ],
            else_actions: [
              # If shield is broken, pass through remaining damage
              %{type: :set_damage, amount: "-state.shield_hp"}
            ]
          },
          # Check if shield should break
          %{
            type: :conditional,
            condition:
              "state.hits_remaining <= 0 or state.shield_hp <= 0 or skill_id == :al_holylight or skill_id == :pa_pressure",
            then_actions: [
              %{type: :remove_status, status: :sc_kyrie}
            ]
          }
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Magnificat - Increases SP regeneration rate
  sc_magnificat: %{
    properties: [:buff],
    modifiers: %{
      # Doubles SP regeneration rate
      sp_regen: 100
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_magnificat_icon},
      %{type: :set_visual_effect, effect: :magnificat_aura}
    ],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Gloria - Increases LUK
  sc_gloria: %{
    properties: [:buff],
    modifiers: %{
      # Fixed +30 LUK bonus
      luk: 30
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_gloria_icon},
      %{type: :set_visual_effect, effect: :gloria_aura}
    ],
    calc_flags: [:luk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Lex Aeterna - Doubles damage taken
  sc_aeterna: %{
    properties: [:debuff],
    on_apply: [
      %{type: :notify_client, packet: :sc_aeterna_icon},
      %{type: :set_visual_effect, effect: :lex_aeterna_mark}
    ],
    on_damaged: [
      %{
        type: :conditional,
        # Double all damage except Soul Burn
        condition: "skill_id != :pf_soulburn and (src_type != :mer or not skill_id)",
        then_actions: [
          # Double damage
          %{type: :modify_damage, multiplier: 2.0}
        ]
      },
      %{
        type: :conditional,
        # Remove after taking damage, except for specific conditions with Breaker skill
        condition:
          "skill_id != :asc_breaker or (skill_id == :asc_breaker and dmg_type != :physical)",
        then_actions: [
          %{type: :remove_status, status: :sc_aeterna}
        ]
      }
    ],
    conflicts_with: [:sc_freeze],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Adrenaline Rush - ASPD increase for specific weapon types
  sc_adrenaline: %{
    properties: [:buff],
    modifiers: %{
      # 30% ASPD increase
      aspd_rate: 30
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_adrenaline_icon},
      %{type: :remove_status, status: :sc_decreaseagi},
      %{type: :remove_status, status: :sc_quagmire}
    ],
    calc_flags: [:aspd],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Weapon Perfection - Ignores size penalties
  sc_weaponperfection: %{
    properties: [:buff],
    modifiers: %{
      # Flag to disable size adjustment penalties
      ignore_size_adjustment: true
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_weaponperfection_icon}
    ],
    calc_flags: [:damage],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Overthrust - Increases weapon damage with a chance to break
  sc_overthrust: %{
    properties: [:buff],
    modifiers: %{
      # 25% attack increase
      watk_rate: 25
    },
    instance_state: %{
      # Chance to break weapon 0.1%
      break_chance: 1
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_overthrust_icon}
    ],
    on_attack: [
      %{
        type: :conditional,
        # Check for weapon break chance
        condition: "rand(1000) < state.break_chance",
        then_actions: [
          %{type: :break_equipment, slot: :weapon},
          %{type: :notify_client, packet: :weapon_break_animation}
        ]
      }
    ],
    calc_flags: [:watk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Maximize Power - Forces maximum damage for all attacks
  sc_maximizepower: %{
    properties: [:buff],
    modifiers: %{
      # Flag to use maximum damage
      maximize_damage: true
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_maximizepower_icon}
    ],
    on_attack: [
      # Ensure all damage calculations use the maximum possible damage
      %{type: :maximize_damage}
    ],
    calc_flags: [:damage],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Trick Dead - Feigns death to avoid combat
  sc_trickdead: %{
    properties: [:buff, :prevents_movement, :prevents_skills, :prevents_attack],
    flags: [:no_move, :no_attack, :no_skill, :no_magic],
    on_apply: [
      %{type: :notify_client, packet: :sc_trickdead_icon},
      # Send vanish packet with trickdead type (4)
      %{type: :set_visual_effect, effect: :play_dead_animation},
      %{type: :notify_client, packet: :vanish, data: %{type: 4}}
    ],
    on_remove: [
      # Make player reappear
      %{type: :notify_client, packet: :appear}
    ],
    on_move: [
      %{type: :remove_status, status: :sc_trickdead}
    ],
    on_attacked: [
      %{type: :remove_status, status: :sc_trickdead}
    ],
    on_attack: [
      %{type: :remove_status, status: :sc_trickdead}
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Loud/Shout - Increases STR
  sc_loud: %{
    properties: [:buff],
    modifiers: %{
      # +4 STR
      str: 4
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_loud_icon},
      %{type: :remove_status, status: :sc_quagmire},
      %{type: :remove_status, status: :sc_concentrate}
    ],
    calc_flags: [:str],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Magic Power - Increases MATK for next spell
  sc_magicpower: %{
    properties: [:buff],
    instance_state: %{
      # Status: 0 = ready to use, 1 = active and running
      active: 0
    },
    modifiers: %{
      # MATK increase by percentage when active
      matk_rate: "state.active * (5 * val1)"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_magicpower_icon},
      # Initialize state: 0 = ready to be used
      %{type: :set_state, key: :active, value: 0}
    ],
    calc_flags: [:matk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Auto Berserk - Auto-triggers berserk at low HP
  sc_autoberserk: %{
    properties: [:buff],
    flags: [:infinite_duration],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Enchant Arms - Weapon element enchantment
  sc_enchantarms: %{
    properties: [:buff],
    modifiers: %{
      # Apply element to weapon based on val1
      atk_ele: "val1"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_enchantarms_icon},
      # Remove other weapon enchantments
      %{type: :remove_status, status: :sc_encpoison},
      %{type: :remove_status, status: :sc_aspersio},
      %{type: :remove_status, status: :sc_fireweapon},
      %{type: :remove_status, status: :sc_waterweapon},
      %{type: :remove_status, status: :sc_windweapon},
      %{type: :remove_status, status: :sc_earthweapon},
      %{type: :remove_status, status: :sc_shadowweapon},
      %{type: :remove_status, status: :sc_ghostweapon}
    ],
    calc_flags: [:atk_ele],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Spear Quicken - ASPD increase for spear users
  sc_spearquicken: %{
    properties: [:buff],
    modifiers: %{
      # Fixed ASPD bonus based on skill level
      aspd_rate: "val2",
      # HIT bonus
      hit: "val1 * 3",
      # Flee bonus
      flee: "val1 * 2"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_spearquicken_icon},
      %{type: :remove_status, status: :sc_decreaseagi},
      %{type: :remove_status, status: :sc_quagmire}
    ],
    calc_flags: [:aspd, :hit, :flee],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Berserk - Extreme attack buff with drawbacks
  sc_berserk: %{
    properties: [:buff],
    modifiers: %{
      # +200% ATK
      atk_rate: 200,
      # +25% ASPD
      aspd_rate: 25,
      # Drain SP to 0
      sp: -999,
      # +20% movement speed
      movement_speed: -20,
      # Def reduction to 0
      def_rate: -100,
      # MDef reduction to 0
      mdef_rate: -100
    },
    flags: [:no_regen, :cannot_use_skills, :no_pickup],
    on_apply: [
      %{type: :notify_client, packet: :sc_berserk_icon},
      # Recover 100% HP on activation
      %{type: :heal, formula: "max_hp"},
      # Drain all SP
      %{type: :damage, formula: "sp"},
      # Set visual effect
      %{type: :set_visual_effect, effect: :berserk_aura}
    ],
    on_remove: [
      # When berserk ends, reduce HP to 10% if it was not triggered by dead state
      %{
        type: :conditional,
        condition: "not is_dead",
        then_actions: [
          %{type: :damage, formula: "hp * 0.9", ignore_def: true}
        ]
      }
    ],
    # Blocked by certain status effects
    conflicts_with: [:sc_Stone, :sc_sleep, :sc_stun, :sc_freeze],
    # Cannot be removed by normal means
    prevented_by: [:sc_refresh, :sc_inspiration],
    calc_flags: [:atk, :aspd, :def, :mdef, :speed]
  },

  # Sacrifice - Sacrifice HP for guaranteed hits
  sc_sacrifice: %{
    properties: [:buff],
    instance_state: %{
      # Number of hits remaining
      hits_remaining: 5
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_sacrifice_icon},
      %{type: :set_state, key: :hits_remaining, value: "val2"}
    ],
    on_attack: [
      # Ensure all attacks hit
      %{type: :force_hit},
      # Deal 9% of max HP damage to self per hit
      %{type: :damage, formula: "max_hp * 0.09", ignore_def: true},
      # Reduce hit counter
      %{type: :set_state, key: :hits_remaining, value: "-1"},
      # Check if all hits used
      %{
        type: :conditional,
        condition: "state.hits_remaining <= 0",
        then_actions: [
          %{type: :remove_status, status: :sc_sacrifice}
        ]
      }
    ],
    # Cannot be removed by normal means
    flags: [:infinite_duration],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Gospel - Area buff with multiple effects
  sc_gospel: %{
    properties: [:buff],
    modifiers: %{
      # All stats +20
      str: 20,
      agi: 20,
      vit: 20,
      int: 20,
      dex: 20,
      luk: 20,
      # Defense +25%
      def_rate: 25,
      # Magic defense +25%
      mdef_rate: 25,
      # Maximum HP/SP +30%
      maxhp_rate: 30,
      maxsp_rate: 30
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_gospel_icon},
      %{type: :set_visual_effect, effect: :gospel_aura}
    ],
    calc_flags: [:str, :agi, :vit, :int, :dex, :luk, :def, :mdef, :maxhp, :maxsp],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Autoguard - Chance to block physical attacks
  sc_autoguard: %{
    properties: [:buff],
    instance_state: %{
      # Blocking chance
      block_chance: "5 + 5 * val1"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_autoguard_icon}
    ],
    conflicts_with: [:sc_autoguard],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Reflectshield - Reflects damage back to attacker
  sc_reflectshield: %{
    properties: [:buff],
    instance_state: %{
      # Reflection percentage
      reflect_percent: "10 + 3 * val1"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_reflectshield_icon}
    ],
    on_damaged: [
      %{
        type: :conditional,
        condition: "dmg_type == :physical and skill_id == 0",
        then_actions: [
          # Reflect damage back to attacker
          %{
            type: :reflect_damage,
            percentage: "state.reflect_percent"
          }
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Devotion - Transfers damage to paladin
  sc_devotion: %{
    properties: [:buff],
    instance_state: %{
      # Caster ID who is protecting this character
      protector_id: "caster.id",
      # Distance threshold before breaking devotion
      max_distance: "val3"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_devotion_icon},
      %{type: :set_visual_effect, effect: :devotion_link}
    ],
    on_damage: [
      # Transfer damage to protector
      %{
        type: :conditional,
        # Always check if protector is valid
        condition: "true",
        then_actions: [
          %{
            type: :transfer_damage,
            percentage: 100,
            target: "state.protector_id"
          }
        ]
      }
    ],
    on_move: [
      # Check distance to protector on movement
      %{
        type: :conditional,
        condition: "distance_to(state.protector_id) > state.max_distance",
        then_actions: [
          %{type: :remove_status, status: :sc_devotion}
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Energy Coat - Magic damage reduction based on SP
  sc_energycoat: %{
    properties: [:buff],
    modifiers: %{
      # Visual effect for energy coating
      energy_coat_active: true
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_energycoat_icon},
      %{type: :set_visual_effect, effect: :energy_coat_aura}
    ],
    on_damaged: [
      %{
        type: :conditional,
        # Only for weapon attacks and certain skills
        condition:
          "skill_id == :gn_hells_plant_atk or (dmg_flag == :weapon and skill_id != :ws_carttermination)",
        then_actions: [
          # Calculate SP percentage and consume SP/modify damage accordingly
          %{
            type: :conditional,
            condition: "sp >= (10 + 5 * ((sp * 100 / max_sp - 1) / 20)) * max_sp / 1000",
            then_actions: [
              # Consume SP
              %{
                type: :damage,
                formula: "(10 + 5 * ((sp * 100 / max_sp - 1) / 20)) * max_sp / 1000"
              },
              # Damage reduction: 6% + 6% every 20% SP
              %{
                type: :modify_damage,
                multiplier: "1.0 - (6 * (1 + ((sp * 100 / max_sp - 1) / 20))) / 100.0"
              }
            ],
            else_actions: [
              # Not enough SP, remove Energy Coat
              %{type: :remove_status, status: :sc_energycoat}
            ]
          }
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Broken Armor - Permanently prevents armor from functioning  
  sc_brokenarmor: %{
    properties: [:debuff],
    modifiers: %{
      # Complete armor nullification
      armor_broken: true
    },
    flags: [:infinite_duration],
    on_apply: [
      %{type: :notify_client, packet: :sc_brokenarmor_icon}
    ],
    calc_flags: [:def],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Broken Weapon - Permanently prevents weapon from functioning
  sc_brokenweapon: %{
    properties: [:debuff],
    modifiers: %{
      # Complete weapon nullification
      weapon_broken: true
    },
    flags: [:infinite_duration],
    on_apply: [
      %{type: :notify_client, packet: :sc_brokenweapon_icon}
    ],
    calc_flags: [:watk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Hallucination - Causes visual distortions and damage randomization
  sc_hallucination: %{
    properties: [:debuff],
    on_apply: [
      %{type: :notify_client, packet: :sc_hallucination_icon},
      %{type: :set_visual_effect, effect: :hallucination_distortion}
    ],
    on_damaged: [
      # Randomize damage display (not actual damage)
      %{
        type: :modify_display_damage,
        # Randomly display damage in different magnitude orders
        multiplier: "rand() % 5 + 1"
      }
    ],
    immunity: [:boss],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Weight 50% - Overweight status at 50% capacity
  sc_weight50: %{
    properties: [:debuff],
    modifiers: %{
      # No natural healing while overweight
      hp_regen: -100,
      sp_regen: -100
    },
    flags: [:no_remove_on_death, :no_clear_buff, :no_save, :no_dispel, :no_force_end],
    on_apply: [
      %{type: :notify_client, packet: :sc_weight50_icon}
    ],
    calc_flags: [:regen],
    # Mutually exclusive with weight90
    end_on_start: [:sc_weight90],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Weight 90% - Major overweight status at 90% capacity
  sc_weight90: %{
    properties: [:debuff],
    modifiers: %{
      # No natural healing while overweight
      hp_regen: -100,
      sp_regen: -100
    },
    flags: [
      :no_remove_on_death,
      :no_clear_buff,
      :stop_attacking,
      :no_save,
      :no_dispel,
      :no_force_end
    ],
    on_apply: [
      %{type: :notify_client, packet: :sc_weight90_icon}
    ],
    calc_flags: [:regen],
    # Mutually exclusive with weight50
    end_on_start: [:sc_weight50],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # ASPD Potion 0 - Basic ASPD potion (level 1)
  sc_aspdpotion0: %{
    properties: [:buff],
    modifiers: %{
      # ASPD reduction: -50 * (2 + 0) = -100
      aspd: -100
    },
    flags: [:no_clearance, :overlap_ignore_level],
    on_apply: [
      %{type: :notify_client, packet: :sc_aspdpotion0_icon}
    ],
    calc_flags: [:aspd],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # ASPD Potion 1 - Improved ASPD potion (level 2)
  sc_aspdpotion1: %{
    properties: [:buff],
    modifiers: %{
      # ASPD reduction: -50 * (2 + 1) = -150  
      aspd: -150
    },
    flags: [:no_clearance, :overlap_ignore_level],
    on_apply: [
      %{type: :notify_client, packet: :sc_aspdpotion1_icon}
    ],
    calc_flags: [:aspd],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # ASPD Potion 2 - Advanced ASPD potion (level 3)
  sc_aspdpotion2: %{
    properties: [:buff],
    modifiers: %{
      # ASPD reduction: -50 * (2 + 2) = -200
      aspd: -200
    },
    flags: [:overlap_ignore_level],
    on_apply: [
      %{type: :notify_client, packet: :sc_aspdpotion2_icon}
    ],
    calc_flags: [:aspd],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # ASPD Potion 3 - Supreme ASPD potion (level 4)
  sc_aspdpotion3: %{
    properties: [:buff],
    modifiers: %{
      # ASPD reduction: -50 * (2 + 3) = -250
      aspd: -250
    },
    flags: [:no_clearance, :overlap_ignore_level],
    on_apply: [
      %{type: :notify_client, packet: :sc_aspdpotion3_icon}
    ],
    calc_flags: [:aspd],
    prevented_by: [:sc_refresh, :sc_inspiration]
  }
}
