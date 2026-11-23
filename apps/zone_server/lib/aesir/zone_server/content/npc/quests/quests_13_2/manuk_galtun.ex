defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ManukGaltun do
  @moduledoc """
  Strom challenges the player to prove their strength.

  ## Behavior

  - Assigns a hunt for Rata and Duneyrr after the required story progress.
  - Rewards both completed hunts with experience and Manuk coins.

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
        map: "manuk",
        x: 252,
        y: 116,
        dir: 3,
        sprite: 450,
        name: "Manuk Galtun",
        scope: :shared,
        unique_name: "Manuk Galtun#ep13_2day"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 2}]) == 0 do
      ctx
      |> mes("Wait a moment!!")
      |> mes("You have too many items.")
      |> mes("You can't receive this.")
      |> mes("Lighten your weight and")
      |> mes("try again.")
      |> close()
    else
      talk_when_ready(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp talk_when_ready(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) > 99 do
      if get_char_var(ctx, :ep13_2_days01, 0) == 0 do
        {ctx, choice} =
          ctx
          |> mes("[Strom]")
          |> mes("Hello.")
          |> mes("You're a human right?")
          |> mes("My name is Strom.")
          |> next()
          |> mes("[Strom]")
          |> mes("But, you guys seem so weak.")
          |> mes("You don't have solid skin nor enough power.")
          |> next()
          |> mes("[Strom]")
          |> mes("How did you guys get here?")
          |> next()
          |> mes("[Strom]")
          |> mes(
            "Your language seems gentle, but it seems like you are here to create more tension."
          )
          |> next()
          |> select(["Keep the peace.", "..."])

        case choice do
          1 ->
            ctx =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Yes, we humans are smaller than you... but...")
              |> mes("we have been training ourselves to be strong.")
              |> next()

            ctx =
              ctx
              |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
              |> mes("Now let me show you that")
              |> mes("we can match your strength!")
              |> next()

            if get_char_var(ctx, :ep13_mdrama, 0) > 5 do
              ctx
              |> mes("[Strom]")
              |> mes("Anyway...")
              |> mes(
                "Some bad things happened to my one of my colleagues in that cave you found recently."
              )
              |> next()
              |> mes("[Strom]")
              |> mes("There're monsters called ^4d4dffRata^000000 and ^4d4dffDueyrr^000000.")
              |> mes("If you terminate them, I would regard you as a decent and strong person.")
              |> set_char_var(:ep13_2_days01, 1)
              |> setquest(7074)
              |> setquest(7075)
              |> close()
            else
              ctx
              |> mes("[Strom]")
              |> mes("...is that it?")
              |> mes("Let me think.")
              |> mes("Since you have so much confidence in their abilities...")
              |> mes("I will find you a worthy challenge to prove it.")
              |> close()
            end

          2 ->
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Yes, but human beings can be stronger when they all work together.")
            |> close()

          _ ->
            ctx
        end
      else
        if get_char_var(ctx, :ep13_2_days01, 0) == 1 do
          ctx = set_local(ctx, :qst_cpl01, checkquest(ctx, 7074, :hunting))
          ctx = set_local(ctx, :qst_cpl02, checkquest(ctx, 7075, :hunting))

          if get_local(ctx, :qst_cpl01, 0) == 2 and get_local(ctx, :qst_cpl02, 0) == 2 do
            ctx =
              ctx
              |> mes("[Strom]")
              |> mes(
                "Sure enough... I, the Sapha Galtun, Strom, apologize to you. I should not have been so quick to despise you."
              )
              |> mes("I admit that you are a brave soldier, please feel free to visit Manuk.")
              |> next()
              |> mes("[Strom]")
              |> mes("Although I don't have much to offer, please accept these coins.")
              |> mes("If you need to buy something, you can use them.")
              |> completequest(7074)
              |> completequest(7075)
              |> set_char_var(:ep13_2_days01, 2)

            ctx =
              if Rathena.truthy?(checkre(ctx, 3)) do
                getexp(ctx, 50_000, 30_000)
              else
                getexp(ctx, 500_000, 300_000)
              end

            ctx |> give_item(6080, 10) |> close()
          else
            ctx
            |> mes("[Strom]")
            |> mes("If you want to show you're so strong...")
            |> mes("Please find and defeat the Rata and Duneyrr in the cave.")
            |> close()
          end
        else
          ctx
          |> mes("[Strom]")
          |> mes(
            "Here icy climate is not suitable for biological survival, but we do not feel cold,"
          )
          |> mes("so we're not very concerned about it.")
          |> next()
          |> mes("[Strom]")
          |> mes("But... you're different.")
          |> mes("In such cold weather, you are best to don Hillslions fur...")
          |> close()
        end
      end
    else
      ctx
      |> mes("[Manuk Galtun]")
      |> mes("Arpe? Yu osp sad?")
      |> mes("EW pisdn psa?")
      |> mes("We psis?")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
