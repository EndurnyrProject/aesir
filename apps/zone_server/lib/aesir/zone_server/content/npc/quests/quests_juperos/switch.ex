defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Switch do
  @moduledoc """
  Starts the Juperos elevator challenge using Crest Pieces.

  ## Behavior

  - Accepts Crest Pieces and activates the elevator reception challenge.
  - Announces the challenge and starts the first guard wave.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jupe_ele_r",
        x: 51,
        y: 98,
        dir: 0,
        sprite: 844,
        name: "Switch",
        scope: :shared,
        unique_name: "Switch#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_server_temp_var(ctx, "JupeElevatorInUse", 0) == 1 do
      ctx
      |> mes("^3355FFIt's some sort of")
      |> mes("lever that looks like")
      |> mes("it was already pulled")
      |> mes("by someone else.^000000")
      |> close()
    else
      {ctx, choice} =
        ctx
        |> cutin("5", 2)
        |> mes("^3355FFIt's some sort of")
        |> mes("lever that's located")
        |> mes("next to four empty slots.^000000")
        |> next()
        |> select(["Pull the lever.", "Leave it alone."])

      case choice do
        1 ->
          pull_lever(ctx)

        2 ->
          ctx
          |> mes("^3355FFWho knows what")
          |> mes("this lever may do?")
          |> mes("You'll never know unless")
          |> mes("you have the courage to try.^000000")
          |> close()
          |> cutin("5", 255)

        _ ->
          ctx
      end
    end
  end

  defp pull_lever(ctx) do
    ctx =
      ctx
      |> mes("^3355FF*Snap Snap*^000000")
      |> next()
      |> mes("^3355FFYou pull the lever,")
      |> mes("but nothing happened.")
      |> mes("You probably need to")
      |> mes("insert the correct objects")
      |> mes("into the slots in order")
      |> mes("for the lever to operate.^000000")
      |> next()

    if count_item(ctx, 7356) > 0 and count_item(ctx, 7359) > 0 and count_item(ctx, 7357) > 0 and
         count_item(ctx, 7358) > 0 do
      {ctx, choice} = select(ctx, ["Insert all of your Crest Pieces."])

      case choice do
        1 ->
          insert_crests(ctx)

        _ ->
          ctx
      end
    else
      if count_item(ctx, 7356) > 0 or count_item(ctx, 7359) > 0 or count_item(ctx, 7357) > 0 or
           count_item(ctx, 7358) > 0 do
        {ctx, _} = select(ctx, ["Insert Crest Pieces."])

        ctx
        |> mes("^3355FFRight now, you don't")
        |> mes("have enough Crest Pieces")
        |> mes("to place into all four of these")
        |> mes(
          "slots. You'll need to find and^FFFFFF ^3355FF bring them all to make this work.^000000"
        )
        |> close()
        |> cutin("5-1", 255)
      else
        ctx
        |> mes("^3355FFYou need to find")
        |> mes("some kind of object")
        |> mes("that you can fit into")
        |> mes("each of these four slots...^000000")
        |> close()
        |> cutin("5-1", 255)
      end
    end
  end

  defp insert_crests(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3300FF*Snap!*^000000")
      |> mes("^3300FFStrangely enough,")
      |> mes("all four of the Crest")
      |> mes("Pieces fit perfectly into")
      |> mes("the slots and begin to")
      |> mes("emit a strange light.^000000")
      |> cutin("5-1", 2)
      |> specialeffect(:sphere)
      |> delitem(7356, 1)
      |> delitem(7359, 1)
      |> delitem(7357, 1)
      |> delitem(7358, 1)
      |> next()
      |> select(["Pull out the Crest Pieces.", "Pull the lever."])

    case choice do
      1 ->
        ctx
        |> cutin("5", 2)
        |> mes("^3355FFYou pull out all")
        |> mes("the Crest Pieces")
        |> mes("that you inserted")
        |> mes("into the slots.^000000")
        |> give_item(7356, 1)
        |> give_item(7359, 1)
        |> give_item(7357, 1)
        |> give_item(7358, 1)
        |> close()
        |> cutin("5", 255)

      2 ->
        if get_server_temp_var(ctx, "JupeElevatorInUse", 0) == 1 do
          ctx
          |> mes("^3355FFIt's strange,")
          |> mes("but this lever has")
          |> mes("already been pulled.^000000")
          |> close()
          |> cutin("5", 255)
        else
          ctx
          |> mes("^3355FFOnce you pull the lever,")
          |> mes("the Crest Piece slots are")
          |> mes("suddenly covered, making")
          |> mes("them irretrievable, and the")
          |> mes("ground begins to shake")
          |> mes("violently. This isn't normal!^000000")
          |> next()
          |> set_server_temp_var("JupeElevatorInUse", 1)
          |> disablenpc("Switch#ufe")
          |> enablenpc("Switch On#ufe")
          |> initnpctimer()
          |> specialeffect2(:screen_quake)
          |> soundeffectall("earth_quake.wav", 0)
          |> close()
          |> cutin("5-1", 255)
        end

      _ ->
        ctx
    end
  end

  @impl true
  def on_event("OnTimer2000", ctx) do
    mapannounce(ctx, "jupe_ele_r", "My descendents...", 1, "0x66FF00")
  end

  def on_event("OnTimer3000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele_r",
      "Do you want to know why this city was buried beneath the earth...?",
      1,
      "0x66FF00"
    )
  end

  def on_event("OnTimer7000", ctx) do
    mapannounce(ctx, "jupe_ele_r", "If so, follow my voice...", 1, "0x66FF00")
  end

  def on_event("OnTimer10000", ctx) do
    mapannounce(
      ctx,
      "jupe_ele_r",
      "I shall let you see for yourself what you desire to know...",
      1,
      "0x66FF00"
    )
  end

  def on_event("OnTimer17000", ctx) do
    mapannounce(ctx, "jupe_ele_r", "Overcome all the hallucinations.", 1, "0xCC6600")
  end

  def on_event("OnTimer20000", ctx) do
    mapannounce(ctx, "jupe_ele_r", "Open your eyes and see past all of the lies.", 1, "0xFF0000")
  end

  def on_event("OnTimer23000", ctx) do
    ctx
    |> mapannounce(
      "jupe_ele_r",
      "I can only maintain this vision for you for 20 minutes.",
      1,
      "0xFF0000"
    )
    |> donpcevent("Elevator Guard1#ufe::OnEnable")
  end

  def on_event("OnTimer27000", ctx) do
    ctx |> mapannounce("jupe_ele_r", "Look! And remember!", 1, "0xFF0000") |> stopnpctimer()
  end
end
