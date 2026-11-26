defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.DwarfBlacksmith35136 do
  @moduledoc """
  Vestri, the dwarf blacksmith who tests Mjolnir Seal adventurers by upgrading a risky Level 4
  weapon for them.

  ## Behavior

  - Outside the Mjolnir seal phase, after it has been broken, or once the quest is over, he
    only chats.
  - Failing any dwarf's test (state 3) or finishing his own (state 2) leaves him with a parting
    remark.
  - While another dwarf's test is still open, asking for help gets the player turned away and
    fails his test.
  - Otherwise, asked for help, he offers to refine a Level 4 weapon at risk of breaking for one
    Oridecon.
  - He refines the chosen equipped weapon once (success or failure decided by its refine
    chance, failure destroys it) and marks his test done; non-refinable, fully refined, safe,
    non-weapon or non-Level 4 items are refused, as is a player without an Oridecon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Zephyrus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - The transpiler read the `EQI_*` equipment slot constants and `IT_WEAPON` as character
    variables (always 0), which listed no equipment in the slot menu and refused every item as
    armor; they are the constant values here.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_01",
        x: 35,
        y: 136,
        dir: 7,
        sprite: 826,
        name: "Dwarf Blacksmith",
        scope: :shared,
        unique_name: "Dwarf Blacksmith#west"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FIsequipcardhack
  alias Aesir.ZoneServer.Content.Npc.Functions.FIsequipidhack
  alias Aesir.ZoneServer.Content.Npc.Functions.FIsequiprefinehack
  alias Aesir.ZoneServer.Script.Rathena

  @oridecon 984

  @item_type_weapon 5

  @menu_slots [6, 7, 8, 9, 3, 2, 0, 1, 5, 4]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        kids_these_days(ctx)

      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> mes("[Vestri]")
        |> mes("I don't feel")
        |> mes("like doing anything")
        |> mes("today. Anything at all...")
        |> next()
        |> mes("[Vestri]")
        |> mes(
          "Someone must have forged something really monstrous, otherwise I wouldn't be feeling so worthless!"
        )
        |> next()
        |> mes("[Vestri]")
        |> mes("Yeah, I think I need a break! Don't you think I need a break, human?")
        |> close()

      get_char_var(ctx, :god_mjo_0, 0) == 11 ->
        ctx
        |> mes("[Vestri]")
        |> mes(
          "There's nothing like taking a relaxing break after putting your heart into your work."
        )
        |> next()
        |> mes("[Vestri]")
        |> mes("What do you think,")
        |> mes("human? Isn't that one")
        |> mes("of life's simple pleasures?")
        |> close()

      get_char_var(ctx, :god_mjo_0, 0) == 10 ->
        kids_these_days(ctx)

      get_char_var(ctx, :god_mjo_0, 0) == 1 ->
        dwarf_test(ctx, :god_mjo_3)

      get_char_var(ctx, :god_mjo_0, 0) == 2 ->
        dwarf_test(ctx, :god_mjo_2)

      get_char_var(ctx, :god_mjo_0, 0) == 0 ->
        ctx
        |> mes("[Vestri]")
        |> mes("It's always a pleasure to engage myself in hard work, especially smithing.")
        |> next()
        |> mes("[Vestri]")
        |> mes("Upgrading is always enjoyable!")
        |> mes(
          "I have no regrets when failure, and I'm always pleased when I'm successful. I'll upgrade everyday to make the best of my life~"
        )
        |> close()

      true ->
        sleeping(ctx)
    end
  end

  defp dwarf_test(ctx, test_var) do
    cond do
      get_char_var(ctx, :god_mjo_1, 0) == 3 or get_char_var(ctx, :god_mjo_2, 0) == 3 or
        get_char_var(ctx, :god_mjo_3, 0) == 3 or get_char_var(ctx, :god_mjo_4, 0) == 3 ->
        ctx
        |> mes("[Vestri]")
        |> mes(
          "I really hope I meet a decent human being next time. So far, I haven't met one useful human."
        )
        |> close()

      get_char_var(ctx, test_var, 0) == 2 ->
        ctx
        |> mes("[Vestri]")
        |> mes(
          "Perfect preparation does not always result in success. There's a point when you've got to just go out and do it."
        )
        |> next()
        |> mes("[Vestri]")
        |> mes("I don't know how")
        |> mes("big your goals are,")
        |> mes("but put your heart into")
        |> mes("whatever it is that you")
        |> mes("plan to accomplish in life.")
        |> close()

      other_test_open?(ctx, test_var) ->
        turn_away(ctx, test_var)

      get_char_var(ctx, test_var, 0) == 1 ->
        choose_weapon(ctx, test_var)

      get_char_var(ctx, test_var, 0) == 0 ->
        offer_upgrade(ctx, test_var)

      true ->
        sleeping(ctx)
    end
  end

  defp other_test_open?(ctx, :god_mjo_3) do
    get_char_var(ctx, :god_mjo_1, 0) == 0 or get_char_var(ctx, :god_mjo_1, 0) == 1 or
      get_char_var(ctx, :god_mjo_2, 0) == 0 or get_char_var(ctx, :god_mjo_2, 0) == 1 or
      get_char_var(ctx, :god_mjo_4, 0) != 0
  end

  defp other_test_open?(ctx, :god_mjo_2) do
    get_char_var(ctx, :god_mjo_1, 0) == 0 or get_char_var(ctx, :god_mjo_1, 0) == 1 or
      get_char_var(ctx, :god_mjo_3, 0) != 0 or get_char_var(ctx, :god_mjo_4, 0) != 0
  end

  defp turn_away(ctx, test_var) do
    case what_do_you_want(ctx) do
      {ctx, 1} ->
        ctx |> earn_it_yourself() |> close()

      {ctx, 2} ->
        ctx
        |> set_char_var(test_var, 3)
        |> mes("[Vestri]")
        |> mes("You didn't answer the question! Now, you've probably got the wrong Dwarf here...")
        |> next()
        |> mes("[Vestri]")
        |> mes(
          "Get out of here, and go to your human Blacksmiths if you want equipment upgrades!"
        )
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp offer_upgrade(ctx, test_var) do
    case what_do_you_want(ctx) do
      {ctx, 1} ->
        ctx |> earn_it_yourself() |> close()

      {ctx, 2} ->
        ctx
        |> mes("[Vestri]")
        |> mes("Huh...")
        |> mes(
          "I don't know how I can be much help to an adventurer like you. Aside from being a Blacksmith..."
        )
        |> next()
        |> mes("[Vestri]")
        |> mes(
          "There's nothing I enjoy more than upgrading high level weapons that are on the verge of breaking."
        )
        |> next()
        |> mes("[Vestri]")
        |> mes(
          "Don't you like the idea of challenging the limit? To me, upgrading feels like climbing unconquered mountains!"
        )
        |> next()
        |> mes("[Vestri]")
        |> mes(
          "Alright. Perhaps I'm meant to help you out, so I'll upgrade a weapon for you. All you need to do is bring me the weapon and material."
        )
        |> next()
        |> set_char_var(test_var, 1)
        |> mes("[Vestri]")
        |> mes(
          "Here's the condition: You've got to bring me a Level 4 Weapon that's been upgraded to the point where it might break. Oh, and bring an Oridecon!"
        )
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp choose_weapon(ctx, test_var) do
    ctx =
      ctx
      |> disable_items()
      |> mes("[Vestri]")
      |> mes("Great...!")
      |> mes("Which one should I upgrade first, huh? My heart is pounding with anticipation...")
      |> next()

    indices = Rathena.put_many(get_local(ctx, :indices, []), 1, @menu_slots, 0)
    {ctx, choice} = select(ctx, String.split(slot_menu(ctx, indices), ":"))
    part = Enum.at(indices, choice, 0)

    cond do
      getequipisequiped(ctx, part) == 0 ->
        close(ctx)

      getequipisenableref(ctx, part) == 0 ->
        ctx
        |> mes("[Vestri]")
        |> mes("What...?!")
        |> mes("This isn't upgradable!")
        |> mes("What the hell do you want")
        |> mes("me to do with this?")
        |> close()

      true ->
        inspect_weapon(ctx, test_var, part)
    end
  end

  defp slot_menu(ctx, indices) do
    Enum.reduce(1..10, get_local(ctx, :"menu$", ""), fn i, menu ->
      slot = Enum.at(indices, i, 0)

      menu =
        if Rathena.truthy?(getequipisequiped(ctx, slot)) do
          menu
          |> Rathena.concat(equip_position_name(ctx, slot))
          |> Rathena.concat("-[")
          |> Rathena.concat(getequipname(ctx, slot))
          |> Rathena.concat("]")
        else
          menu
        end

      Rathena.concat(menu, ":")
    end)
  end

  defp inspect_weapon(ctx, test_var, part) do
    equip_id = getequipid(ctx, part)
    item_type = getiteminfo(ctx, equip_id, 2)
    refine = getequiprefinerycnt(ctx, part)
    cards = Enum.map(0..3, &getequipcardid(ctx, part, &1))

    cond do
      refine >= 10 ->
        ctx
        |> mes("[Vestri]")
        |> mes(
          "Oh, this is excellent! This piece here has been perfectly refined! But this isn't what I want. I can't do any work on this at all."
        )
        |> close()

      getequippercentrefinery(ctx, part) == 100 ->
        ctx
        |> mes("[Vestri]")
        |> mes(
          "This item isn't even a challenge to upgrade. You can get humans to do this kind of beginner's stuff. Get them to refine it first."
        )
        |> next()
        |> mes("[Vestri]")
        |> mes("Come on...")
        |> mes("Bring me something")
        |> mes("that presents an")
        |> mes("element of risk!")
        |> close()

      item_type != @item_type_weapon ->
        ctx
        |> mes("[Vestri]")
        |> mes("Armor?!")
        |> mes("Didn't I tell")
        |> mes("you that I only work")
        |> mes("on Level 4 weapons?")
        |> not_weapon_tail(test_var)

      getequipweaponlv(ctx, part) != 4 ->
        ctx
        |> mes("[Vestri]")
        |> mes("Hey...")
        |> mes("Don't insult me by expecting me to work on anything less than a Level 4 weapon.")
        |> next()
        |> mes("[Vestri]")
        |> mes("Bring me a Level 4 weapon for me to work on next time, got it?")
        |> close()

      true ->
        confirm_upgrade(ctx, test_var, {part, equip_id, refine, cards})
    end
  end

  defp not_weapon_tail(ctx, :god_mjo_3) do
    ctx
    |> next()
    |> mes("[Vestri]")
    |> mes("You can have a human")
    |> mes(
      "Blacksmith work on that kind of stuff! Now, a Dwarf like me needs something that's more of a challenge!"
    )
    |> close()
  end

  defp not_weapon_tail(ctx, :god_mjo_2), do: close(ctx)

  defp confirm_upgrade(ctx, test_var, weapon) do
    {ctx, choice} =
      ctx
      |> mes("[Vestri]")
      |> mes(
        "Okay, let me give you the mandatory warning. If your weapon happens to be destroyed by chance during the upgrade, you'll never see the weapon again."
      )
      |> next()
      |> mes("[Vestri]")
      |> mes(
        "That also means that if the weapon is destroyed, any ^FF0000Cards^000000 inserted into the weapon will also be gone."
      )
      |> next()
      |> mes("[Vestri]")
      |> mes("If you understand,")
      |> mes("then let's get on with it!")
      |> next()
      |> select(["Sure, let's do it!", decline_option(test_var)])

    cond do
      choice == 2 ->
        ctx
        |> mes("[Vestri]")
        |> mes("Bah...!")
        |> mes("How do you survive")
        |> mes("in this world with that")
        |> mes("kind of cowardice?!")
        |> next()
        |> mes("[Vestri]")
        |> mes("Oh, forget it.")
        |> mes("I know you're just being careful. Damn, I was just so eager to get")
        |> mes("to work!")
        |> close()

      count_item(ctx, @oridecon) > 0 ->
        ctx |> delitem(@oridecon, 1) |> check_and_refine(test_var, weapon)

      true ->
        ctx
        |> mes("[Vestri]")
        |> mes("Huh...")
        |> mes("You forgot to")
        |> mes("bring an Oridecon.")
        |> mes("Hurry up and get one.")
        |> close()
    end
  end

  defp decline_option(:god_mjo_3), do: "N-no, I changed my mind!"
  defp decline_option(:god_mjo_2), do: "...no, I am out."

  defp check_and_refine(ctx, test_var, {part, equip_id, refine, [c0, c1, c2, c3]}) do
    {ctx, id_hack} = FIsequipidhack.call(ctx, [part, equip_id])
    {ctx, card_hack} = FIsequipcardhack.call(ctx, [part, c0, c1, c2, c3])
    {ctx, refine_hack} = FIsequiprefinehack.call(ctx, [part, refine])

    if Rathena.truthy?(id_hack) or Rathena.truthy?(card_hack) or Rathena.truthy?(refine_hack) do
      close(ctx)
    else
      ctx
      |> refine_weapon(part)
      |> set_char_var(test_var, 2)
      |> mes("[Vestri]")
      |> mes("Well, my friend,")
      |> mes("if you ever visit my brothers, please give them my regards.")
      |> mes("Take care.")
      |> close()
    end
  end

  defp refine_weapon(ctx, part) do
    if getequippercentrefinery(ctx, part) > :rand.uniform(100) - 1 do
      ctx
      |> mes("^3355FF*Clang Clang!*^000000")
      |> successrefitem(part)
      |> next()
      |> emotion(:smile)
      |> mes("[Vestri]")
      |> mes("Mwahahaha~")
      |> mes("I've still got it!")
      |> mes("So aren't you happy")
      |> mes("with an even more")
      |> mes("powerful weapon?")
      |> next()
    else
      ctx
      |> mes("[Vestri]")
      |> mes("^3355FF*Clang Clang!*^000000")
      |> failedrefitem(part)
      |> next()
      |> emotion(:huk)
      |> mes("[Vestri]")
      |> mes("Waaahhhhh!")
      |> mes("Dear God, no!")
      |> next()
      |> mes("[Vestri]")
      |> mes("I-It's alright!")
      |> mes("Bad things happen")
      |> mes("sometimes. Let's just")
      |> mes("think of it as both us")
      |> mes("of us having a bad day.")
      |> mes("Yeah, no regrets!")
      |> next()
    end
  end

  defp what_do_you_want(ctx) do
    ctx
    |> mes("[Vestri]")
    |> mes("What do you want?")
    |> next()
    |> select(["Nothing.", "Excuse me."])
  end

  defp earn_it_yourself(ctx) do
    ctx
    |> mes("[Vestri]")
    |> mes("If you want something, you should earn it through your own efforts.")
    |> next()
    |> mes("[Vestri]")
    |> mes(
      "No matter what other people say, if you're confident and your will is unwavering, you'll always be satisfied with the results."
    )
  end

  defp kids_these_days(ctx) do
    ctx
    |> earn_it_yourself()
    |> next()
    |> mes("[Vestri]")
    |> mes("What do you think?")
    |> mes("Kids these days...")
    |> close()
  end

  defp sleeping(ctx), do: ctx |> mes("[Vestri]") |> mes("Zzzz Zzzz Zzzz...") |> close()
end
