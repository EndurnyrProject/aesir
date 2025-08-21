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
        on_damage: %{
          condition: %{element: :earth},
          action: :remove_self
        }
      }
    },
    calc_flags: [:def_ele, :def, :mdef, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
  },

  # Freeze - Frozen state with defense penalties
  sc_freeze: %{
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    modifiers: %{
      # Water element level 1
      def_ele: 10,
      # -100% physical defense
      def_rate: -100,
      # -50% magic defense
      mdef_rate: -50
    },
    flags: [:no_move, :no_attack, :no_skill],
    on_apply: [
      %{type: :remove_status, targets: [:sc_aeterna]}
    ],
    calc_flags: [:def_ele, :def, :mdef],
    conflicts_with: [:sc_aeterna],
    prevented_by: [
      :sc_refresh,
      :sc_inspiration,
      :sc_warmer,
      :sc_freeze,
      :sc_burning,
      :sc_protection
    ]
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
    on_damage: %{
      action: :remove_self
    },
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
          formula: "(max_hp / 100 + 7) * (1 + 0.1 * val1)",
          element: :neutral,
          min: 1,
          ignore_def: true
        }
      ]
    },
    on_apply: [
      %{type: :remove_status, targets: [:sc_concentrate, :sc_truesight]},
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
      # Set LUK to 0
      luk: -999,
      # -25% base ATK
      batk_rate: -25,
      # -25% weapon ATK
      watk_rate: -25,
      movement_speed: -10
    },
    calc_flags: [:luk, :batk, :watk, :speed],
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
          damage_type: :sp,
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
          # Ensure HP > 25%
          condition: "hp > max_hp / 4",
          then_actions: [
            %{
              type: :damage,
              # 10% max HP damage per tick
              formula: "max_hp / 10",
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
      # ATK increase percentage
      batk_rate: "val2",
      # Weapon ATK increase
      watk_rate: "val2",
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
    calc_flags: [:batk, :watk, :def, :def2, :hit],
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
          %{type: :increment_state, key: :hits_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.hits_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_endure]}
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
      %{type: :remove_status, targets: [:sc_poison, :sc_truesight]}
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
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_change: :remove_self,
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
      # TODO: Complex ternary operators and cloaking_wall_check() not supported by FormulaCompiler
      # Original: "cloaking_wall_check() ? (val1 >= 10 ? -25 : -(3 * val1 - 3)) : (val1 < 3 ? -300 : -(30 - 3 * val1))"
      # For now, use simplified formula without wall check
      # If val1 >= 10: -25, if val1 < 3: -300, else: -(30 - 3*val1)
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
        # TODO: cloaking_wall_check() is an external function not supported by FormulaCompiler
        # For now, disable this check until we implement a callback system
        # Always false - needs proper implementation
        condition: "0",
        then_actions: [
          %{type: :remove_status, targets: [:sc_cloaking]}
        ]
      }
    ],
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_warp: :remove_self,
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
            target: :enemy,
            duration: "skill_get_time2(:as_enchantpoison, val1)"
          }
        ]
      }
    ],
    on_apply: [
      %{type: :notify_client, packet: :sc_encpoison_icon}
    ],
    on_unequip_weapon: :remove_self,
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
    on_poison_damage: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true},
          %{type: :increment_state, key: :counter_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.counter_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_poisonreact]}
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
            value: "30 * pc_checkskill(caster, :as_poisonreact)"
          },
          %{type: :set_state, key: :boost_mode, value: false},
          %{
            type: :apply_status,
            status: :sc_poison,
            target: :enemy,
            chance: 50,
            duration: "skill_get_time2(:as_poisonreact, val1)"
          },
          %{type: :remove_status, targets: [:sc_poisonreact]}
        ]
      }
    ],
    on_attacked_by_poison_element: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true}
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
      %{
        type: :remove_status,
        targets: [
          :sc_loud,
          :sc_concentrate,
          :sc_truesight,
          :sc_windwalk,
          :sc_magneticfield,
          :sc_cartboost,
          :sc_gn_cartboost,
          :sc_increaseagi,
          :sc_adrenaline,
          :sc_adrenaline2,
          :sc_spearquicken,
          :sc_twohandquicken,
          :sc_onehand,
          :sc_merc_quicken,
          :sc_acceleration
        ]
      }
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
      # If val2 > 0 (not undead/demon), increase stats by val2
      # If val2 = 0 (undead/demon), reduce stats by half
      str: "(val2 > 0) * val2 + (val2 == 0) * (-str / 2)",
      int: "(val2 > 0) * val2 + (val2 == 0) * (-int / 2)",
      dex: "(val2 > 0) * val2 + (val2 == 0) * (-dex / 2)",
      # HIT bonus based on stat increases
      hit: "(val2 > 0) * (val2 * 3) + (val2 == 0) * (-hit / 2)"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_blessing_icon},
      # Remove curse first if present - blessing becomes ineffective  
      %{
        type: :conditional,
        condition: "has_status(:sc_curse)",
        then_actions: [
          %{type: :remove_status, targets: [:sc_curse]},
          %{type: :end_self_application}
        ]
      },
      # Remove stone if present and not cursed
      %{
        type: :conditional,
        condition: "has_status(:sc_stone)",
        then_actions: [
          %{type: :remove_status, targets: [:sc_stone]},
          %{type: :end_self_application}
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
      # AGI increase: 2 + skill_level
      agi: "2 + val1",
      # Movement speed increase (negative = faster)
      movement_speed: "-(val1 + 1) * 25 / 4",
      # ASPD increase
      aspd: "val1"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_increaseagi_icon},
      %{type: :remove_status, targets: [:sc_decreaseagi, :sc_adoramus]}
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
      %{
        type: :remove_status,
        targets: [
          :sc_cartboost,
          :sc_gn_cartboost,
          :sc_increaseagi,
          :sc_adrenaline,
          :sc_adrenaline2,
          :sc_spearquicken,
          :sc_twohandquicken,
          :sc_onehand,
          :sc_merc_quicken,
          :sc_acceleration
        ]
      }
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
      %{type: :remove_status, targets: [:sc_impositio]}
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
    on_cast_start: [
      %{
        type: :modify_cast_time,
        reduction_percent: "state.cast_time_reduction"
      }
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
      %{
        type: :remove_status,
        targets: [
          :sc_encpoison,
          :sc_fireweapon,
          :sc_waterweapon,
          :sc_windweapon,
          :sc_earthweapon,
          :sc_shadowweapon,
          :sc_ghostweapon,
          :sc_enchantarms
        ]
      }
    ],
    on_unequip_weapon: :remove_self,
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
          %{type: :modify_state, key: :shield_hp, value: "-damage"},
          # Reduce hits counter
          %{type: :modify_state, key: :hits_remaining, value: "-1"},
          # Completely block damage if shield has HP left
          %{
            type: :conditional,
            condition: "state.shield_hp >= 0",
            then_actions: [
              %{type: :set_damage, value: 0}
            ],
            else_actions: [
              # If shield is broken, pass through remaining damage
              %{type: :set_damage, value: "-state.shield_hp"}
            ]
          },
          # Check if shield should break
          %{
            type: :conditional,
            condition:
              "state.hits_remaining <= 0 or state.shield_hp <= 0 or skill_id == :al_holylight or skill_id == :pa_pressure",
            then_actions: [
              %{type: :remove_status, targets: [:sc_kyrie]}
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
          %{type: :modify_damage, value: "damage * 2"}
        ]
      },
      %{
        type: :conditional,
        # Remove after taking damage, except for specific conditions with Breaker skill
        condition:
          "skill_id != :asc_breaker or (skill_id == :asc_breaker and dmg_type != :physical)",
        then_actions: [
          %{type: :remove_status, targets: [:sc_aeterna]}
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
      # Check if player has correct weapon type (axe or mace)
      %{
        type: :conditional,
        condition: "not pc_check_weapontype(target, [:axe, :mace])",
        then_actions: [
          %{type: :end_self_application}
        ]
      },
      %{type: :notify_client, packet: :sc_adrenaline_icon},
      %{type: :remove_status, targets: [:sc_decreaseagi, :sc_quagmire]}
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
          %{type: :break_equipment, equip_location: :weapon},
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
      %{type: :notify_client, packet: :vanish, args: %{type: 4}}
    ],
    on_remove: [
      # Make player reappear
      %{type: :notify_client, packet: :appear}
    ],
    on_move: :remove_self,
    on_attacked: :remove_self,
    on_attack: :remove_self,
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
      %{type: :remove_status, targets: [:sc_quagmire, :sc_concentrate]}
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
    on_cast_start: [
      # Activate magic power boost on cast start if not already activated
      %{
        type: :conditional,
        condition: "state.active == 0",
        then_actions: [
          %{type: :set_state, key: :active, value: 1},
          %{type: :notify_client, packet: :sc_magicpower_active}
        ]
      }
    ],
    on_cast_end: [
      # If magic power is active and val2 is 1 (single use), remove after cast
      %{
        type: :conditional,
        condition: "state.active == 1 and val2 == 1",
        then_actions: [
          %{type: :remove_status, targets: [:sc_magicpower]}
        ]
      }
    ],
    calc_flags: [:matk],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Auto Berserk - Auto-triggers berserk at low HP
  sc_autoberserk: %{
    properties: [:buff],
    on_hp_update: [
      # Trigger Berserk when HP falls below 25%
      %{
        type: :conditional,
        condition: "hp < max_hp / 4 and not has_status(:sc_provoke)",
        then_actions: [
          %{
            type: :apply_status,
            status: :sc_provoke,
            duration: 60000,
            values: [10, 0, 0, 1]
          }
        ]
      }
    ],
    # Auto Berserk has infinite duration
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
      %{
        type: :remove_status,
        targets: [
          :sc_encpoison,
          :sc_aspersio,
          :sc_fireweapon,
          :sc_waterweapon,
          :sc_windweapon,
          :sc_earthweapon,
          :sc_shadowweapon,
          :sc_ghostweapon
        ]
      }
    ],
    on_unequip_weapon: :remove_self,
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
      # Check if player has spear equipped
      %{
        type: :conditional,
        condition: "not pc_check_weapontype(target, [:spear])",
        then_actions: [
          %{type: :end_self_application}
        ]
      },
      %{type: :notify_client, packet: :sc_spearquicken_icon},
      %{type: :remove_status, targets: [:sc_decreaseagi, :sc_quagmire]}
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
      %{type: :heal, heal_percent: 100},
      # Drain all SP
      %{type: :damage, damage_type: :sp, formula: "sp"},
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
      %{type: :force_hit, value: true},
      # Deal 9% of max HP damage to self per hit
      %{type: :damage, formula: "max_hp * 0.09", ignore_def: true, target: :self},
      # Reduce hit counter
      %{type: :modify_state, key: :hits_remaining, value: "-1"},
      # Check if all hits used
      %{
        type: :conditional,
        condition: "state.hits_remaining <= 0",
        then_actions: [
          %{type: :remove_status, targets: [:sc_sacrifice]}
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
    on_physical_attack: [
      %{
        type: :conditional,
        condition: "rand(100) < state.block_chance",
        then_actions: [
          # Block damage
          %{type: :set_damage, value: 0},
          # Display blocking animation
          %{type: :notify_client, packet: :autoguard_animation},
          # Apply delay after successful guard
          %{type: :apply_delay, delay: "val2"}
        ]
      }
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
    on_physical_damage: [
      %{
        type: :conditional,
        condition: "dmg_type == :physical and skill_id == 0",
        then_actions: [
          # Reflect damage back to attacker
          %{
            type: :reflect_damage,
            percent: "state.reflect_percent",
            # Cap reflected damage at target's max HP
            max_damage: "status->max_hp",
            ignore_def: false
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
            target_id: "state.protector_id",
            percent: 100
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
          %{type: :remove_status, targets: [:sc_devotion]}
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Provoke - ATK boost with DEF penalty and aggro management
  sc_provoke: %{
    properties: [:debuff],
    modifiers: %{
      # ATK increase: 2 + 3 * skill_level (val2)
      batk_rate: "val2",
      # Weapon ATK increase  
      watk_rate: "val2",
      # DEF reduction: 5 + 5 * skill_level (val3)
      def_rate: "-val3",
      # VIT DEF reduction
      def2_rate: "-val3"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_provoke_icon},
      %{type: :set_state, key: :provoked_by, value: "caster.id"},
      %{
        type: :remove_status,
        targets: [:sc_freeze, :sc_stone, :sc_sleep, :sc_trickdead]
      }
    ],
    on_remove: [
      %{type: :set_state, key: :provoked_by, value: nil}
    ],
    # Auto-provoke duration check
    tick: %{
      interval: 60000,
      condition: "val4 == 1",
      actions: [
        %{type: :remove_status, targets: [:sc_provoke]}
      ]
    },
    calc_flags: [:def, :def2, :batk, :watk],
    immunity: [:boss],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Endure - Hit-based endurance with MDEF bonus
  sc_endure: %{
    properties: [:buff],
    instance_state: %{
      # Number of hits that can be endured (val2 = 7)
      hits_remaining: "val2"
    },
    modifiers: %{
      # MDEF bonus
      mdef: "val1",
      # Delay reduction after being hit
      delay_rate: "-val1 * 10"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_endure_icon},
      # Apply to devotion targets if applicable
      %{
        type: :conditional,
        condition: "is_pc and not (map_flag_gvg or map_flag_bg) and not val4",
        then_actions: [
          %{type: :apply_to_devotion_targets, status: :sc_endure}
        ]
      },
      # Infinite duration if val4 is set
      %{
        type: :conditional,
        condition: "val4",
        then_actions: [
          %{type: :set_infinite_duration}
        ]
      }
    ],
    on_damaged: [
      %{
        type: :conditional,
        # Only reduce hits for non-infinite endure
        condition: "state.hits_remaining > 0 and not val4",
        then_actions: [
          %{type: :increment_state, key: :hits_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.hits_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_endure]}
            ]
          }
        ]
      }
    ],
    calc_flags: [:mdef, :delay],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Two-Hand Quicken - ASPD and critical bonus for two-handed weapons  
  sc_twohandquicken: %{
    properties: [:buff],
    modifiers: %{
      # Fixed ASPD bonus based on skill level
      aspd: "val2",
      # HIT bonus: skill_level * 2
      hit: "val1 * 2",
      # Critical rate bonus: (2 + skill_level) * 10
      cri: "(2 + val1) * 10"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_twohandquicken_icon},
      %{type: :set_visual_effect, effect: :quicken_aura}
    ],
    # Requires weapon to be equipped
    flags: [:require_weapon],
    calc_flags: [:aspd, :hit, :cri],
    conflicts_with: [:sc_decreaseagi],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Concentrate - AGI/DEX boost with concentration
  sc_concentrate: %{
    properties: [:buff],
    modifiers: %{
      # AGI increase: (current_agi - val3) * val2 / 100
      agi: "(agi - val3) * val2 / 100",
      # DEX increase: (current_dex - val4) * val2 / 100
      dex: "(dex - val4) * val2 / 100"
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_concentrate_icon}
    ],
    calc_flags: [:agi, :dex],
    conflicts_with: [:sc_quagmire],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Hiding - Complete invisibility with movement restriction
  sc_hiding: %{
    properties: [:buff],
    modifiers: %{
      # Movement speed penalty unless Tunnel Drive learned
      movement_speed:
        "(pc_checkskill(target, :rg_tunneldrive) > 0) * (-(120 - 6 * pc_checkskill(target, :rg_tunneldrive)))"
    },
    flags: [:hide, :no_pick_item, :no_consume_item, :stop_attacking],
    # Can't move unless Tunnel Drive skill is learned
    states: [:nomovecond],
    on_apply: [
      %{type: :notify_client, packet: :sc_hiding_icon},
      %{type: :set_state, key: :hidden, value: true},
      %{type: :set_visual_effect, effect: :hiding_effect},
      %{
        type: :remove_status,
        targets: [:sc_closeconfine, :sc_closeconfine2]
      }
    ],
    on_remove: [
      %{type: :set_state, key: :hidden, value: false},
      %{type: :remove_visual_effect, effect: :hiding_effect}
    ],
    # Remove hiding on touch/damage/map change
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_change: :remove_self,
    calc_flags: [:speed],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Cloaking - Wall-dependent invisibility with critical bonus
  sc_cloaking: %{
    properties: [:buff],
    modifiers: %{
      # Double critical rate when cloaked
      cri: "cri",
      # Movement speed penalty based on skill level and wall proximity
      # Simplified formula: if val1 >= 10: -25, if val1 < 3: -300, else: -(30 - 3*val1)
      movement_speed:
        "(val1 >= 10) * (-25) + (val1 < 10 and val1 >= 3) * (-(30 - 3 * val1)) + (val1 < 3) * (-300)"
    },
    flags: [:cloak, :no_pick_item, :stop_attacking],
    states: [:nopickitem],
    on_apply: [
      %{type: :notify_client, packet: :sc_cloaking_icon},
      %{type: :set_state, key: :cloaked, value: true},
      %{type: :set_visual_effect, effect: :cloaking_effect}
    ],
    on_remove: [
      %{type: :set_state, key: :cloaked, value: false},
      %{type: :remove_visual_effect, effect: :cloaking_effect}
    ],
    # Remove on touch/damage/map warp
    on_touched: :remove_self,
    on_damaged: :remove_self,
    on_map_warp: :remove_self,
    calc_flags: [:cri, :speed],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Poison React - Counter-poison skill with damage boost
  sc_poisonreact: %{
    properties: [:buff],
    instance_state: %{
      # Number of counters remaining: val1 / 2
      counter_remaining: "val1 / 2",
      # Boost mode flag
      boost_mode: false
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_poisonreact_icon}
    ],
    on_poison_damage: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true},
          %{type: :increment_state, key: :counter_remaining, value: -1},
          %{
            type: :conditional,
            condition: "state.counter_remaining <= 0",
            then_actions: [
              %{type: :remove_status, targets: [:sc_poisonreact]}
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
          # ATK boost: 30% * skill level
          %{
            type: :modify_damage,
            value: "damage * (1.0 + 0.3 * pc_checkskill(caster, :as_poisonreact))"
          },
          %{type: :set_state, key: :boost_mode, value: false},
          # 50% chance to poison target
          %{
            type: :apply_status,
            status: :sc_poison,
            target: :enemy,
            chance: 50,
            duration: "skill_get_time2(:as_poisonreact, val1)"
          },
          %{type: :remove_status, targets: [:sc_poisonreact]}
        ]
      }
    ],
    on_attacked_by_poison_element: [
      %{
        type: :conditional,
        condition: "state.counter_remaining > 0 and not state.boost_mode",
        then_actions: [
          %{type: :set_state, key: :boost_mode, value: true}
        ]
      }
    ],
    prevented_by: [:sc_refresh, :sc_inspiration]
  },

  # Quagmire - AGI/DEX reduction and speed penalty
  sc_quagmire: %{
    properties: [:debuff],
    modifiers: %{
      # AGI reduction: -val2
      agi: "-val2",
      # DEX reduction: -val2  
      dex: "-val2",
      # ASPD penalty: +val2 (higher is slower)
      aspd: "val2",
      # Movement speed penalty: +50%
      movement_speed: 50
    },
    on_apply: [
      %{type: :notify_client, packet: :sc_quagmire_icon},
      # Remove all speed/agility buffs
      %{
        type: :remove_status,
        targets: [
          :sc_loud,
          :sc_concentrate,
          :sc_truesight,
          :sc_windwalk,
          :sc_magneticfield,
          :sc_cartboost,
          :sc_gn_cartboost,
          :sc_increaseagi,
          :sc_adrenaline,
          :sc_adrenaline2,
          :sc_spearquicken,
          :sc_twohandquicken,
          :sc_onehand,
          :sc_merc_quicken,
          :sc_acceleration
        ]
      }
    ],
    calc_flags: [:agi, :dex, :aspd, :speed],
    conflicts_with: [:sc_speedup1],
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
    on_magic_damaged: [
      %{
        type: :conditional,
        # Only for weapon attacks and certain skills
        condition:
          "skill_id == :gn_hells_plant_atk or (dmg_flag == :weapon and skill_id != :ws_carttermination)",
        then_actions: [
          # Calculate SP percentage: (current_sp * 100 / max_sp) - 1
          %{
            type: :set_variable,
            name: :sp_percent,
            value: "(sp * 100 / max_sp) - 1"
          },
          # SP intervals: divide by 20 (uses 20% SP intervals)
          %{
            type: :set_variable,
            name: :sp_interval,
            value: "sp_percent / 20"
          },
          # SP cost: 1% + 0.5% per every 20% SP
          %{
            type: :set_variable,
            name: :sp_cost,
            value: "(10 + 5 * sp_interval) * max_sp / 1000"
          },
          # Check if enough SP for cost
          %{
            type: :conditional,
            condition: "sp >= sp_cost",
            then_actions: [
              # Consume SP
              %{type: :damage, damage_type: :sp, formula: "sp_cost"},
              # Damage reduction: 6% + 6% every 20% SP
              %{
                type: :modify_damage,
                value: "damage * (1.0 - (6 * (1 + sp_interval)) / 100.0)"
              }
            ],
            else_actions: [
              # Not enough SP, remove Energy Coat
              %{type: :remove_status, targets: [:sc_energycoat]}
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
    on_damage_display: [
      # Randomize damage display (not actual damage)
      %{
        type: :modify_display_damage,
        # Randomly display damage in different magnitude orders
        formula: "rand() % 5 + 1",
        transformation: [
          %{digit: 1, display: "rand() % 10"},
          %{digit: 2, display: "rand() % 100"},
          %{digit: 3, display: "rand() % 1000"},
          %{digit: 4, display: "rand() % 10000"},
          %{digit: 5, display: "rand() % 100000"}
        ]
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
