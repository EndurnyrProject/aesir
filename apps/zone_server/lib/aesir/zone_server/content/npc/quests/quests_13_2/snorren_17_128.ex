defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Snorren17128 do
  @moduledoc """
  Helps Snorren and Luik speak with a Laphine and find Ogen.

  ## Behavior

  - Advances the Two Tribes quest when the player understands Snorren and brings evidence.
  - Gives different dialog according to the quest stage and equipment.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_in01",
        x: 17,
        y: 128,
        dir: 5,
        sprite: 454,
        name: "Snorren",
        scope: :shared,
        unique_name: "Snorren#ep13md_15"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx
        |> mes("Wait a moment!!")
        |> mes("You have too many items.")
        |> mes("You can't receive this.")
        |> mes("Lighten your weight and")
        |> mes("try again.")
        |> close()

      is_equipped(ctx, 2782) != 1 ->
        ctx
        |> mes("[Snorren]")
        |> mes("We rs...")
        |> mes("F as d dd ")
        |> mes("Tb ds dfw we!")
        |> mes("Nd fs asd as...!")
        |> close()

      true ->
        talk_quest(ctx, get_char_var(ctx, :ep13_mdrama, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_quest(ctx, stage) do
    case stage do
      18 ->
        ctx =
          ctx
          |> mes("[Snorren]")
          |> mes("Here, Luik. He said this is a cure for Laphine.")
          |> mes("Should we just let her eat it as it is?")
          |> next()
          |> mes("[Snorren]")
          |> mes("Uh.. and your name was..?")
          |> next()

        {ctx, _} =
          select(
            ctx,
            String.split(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ""), ":")
          )

        ctx = ctx |> mes("[Snorren]") |> mes("Yeah, Right.")

        ctx
        |> mes(
          Rathena.concat(
            Rathena.concat("", char_name(ctx, 0)),
            ", you should try talking to that Laphine..."
          )
        )
        |> mes("Let's hear her story.")
        |> set_char_var(:ep13_mdrama, 19)
        |> changequest(7064, 7065)
        |> close()

      19 ->
        ctx
        |> mes("[Snorren]")
        |> mes("Please help me translater.")
        |> mes("We'll be watching as you speak to her.")
        |> mes("Right, Luik?")
        |> next()
        |> mes("[Luik]")
        |> mes("Maybe.")
        |> mes("Let's ask her what happened, before it is too late.")
        |> close()

      20 ->
        ctx
        |> mes("[Snorren]")
        |> mes("Let's listen to her story.")
        |> mes("Why don't we start from... Why does she want a bradium?")
        |> next()
        |> mes("[Snorren]")
        |> mes("This part must be told to Luik in exact detail.")
        |> close()

      21 ->
        ctx
        |> mes("[Snorren]")
        |> mes("What should I do if the Sapha in the Cave is really Ogen...?")
        |> mes("Ogen... What should I do if anything happened to him...?")
        |> close()

      22 ->
        if count_item(ctx, 6085) > 0 and count_item(ctx, 6084) > 0 do
          {ctx, _} =
            ctx
            |> mes("[Luik]")
            |> mes("...This Bradium has not been refined properly...")
            |> mes("This would be no help...")
            |> mes("and, this muffler...")
            |> next()
            |> mes("[Snorren]")
            |> mes("This is Ogen's! Ogen's muffler!")
            |> mes("Luik! Ogen! This is Ogen!")
            |> mes("Unrefined Bradium!")
            |> next()
            |> mes("[Snorren]")
            |> mes("Lu.. Luik. Ogen.. Ogen...?!")
            |> mes("I'm going to Ogen!")
            |> mes("Where is that cave?! Where!")
            |> next()
            |> select(["Calm down!"])

          ctx =
            ctx
            |> mes("[Luik]")
            |> mes("Yeah. Listen to him, calm down. Snorren.")
            |> mes("If it is Ogen... We could be able to save him if we make haste.")
            |> next()
            |> mes("[Luik]")
            |> mes("Snorren. Go to Refinery and get the finest bradium...")
            |> mes("Save him.")
            |> next()
            |> mes("[Luik]")

          ctx
          |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), "...eh?..."))
          |> mes("Please look after Snorren...and Ogen.")
          |> mes("This Laphine, I mean Terra...")
          |> mes("She truly wanted to save Ogen...")
          |> next()
          |> mes("[Luik]")
          |> mes("I will talk to my superiors to try and settle this matter...")
          |> mes("Please save Ogen.")
          |> delitem(6085, 1)
          |> delitem(6084, 1)
          |> set_char_var(:ep13_mdrama, 23)
          |> changequest(7067, 7068)
          |> close()
        else
          ctx
          |> mes("[Luik]")
          |> mes("You should bring something that can prove it?")
          |> mes("... We have been fighting them for so long, it is hard for us to believe you.")
          |> next()
          |> mes("[Snorren]")
          |> mes("...Yes... regardless of anything, just to prove what you say is true.")
          |> close()
        end

      23 ->
        ctx
        |> mes("[Snorren]")
        |> mes("Hurry up and take the lead!")
        |> mes("Which way should we go now?")
        |> close()

      _ ->
        ctx
        |> mes("[Snorren]")
        |> mes("How did you get in here?!")
        |> mes("Get out!")
        |> close()
    end
  end
end
