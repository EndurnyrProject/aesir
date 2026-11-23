defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ManukEngineer do
  @moduledoc """
  The Manuk engineer collects bradium for the Sapha.

  ## Behavior

  - Offers a repeatable collection quest, rewards completed deliveries, and checks the cooldown.
  - Explains the use of bradium.

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
        x: 378,
        y: 276,
        dir: 3,
        sprite: 453,
        name: "Manuk Engineer",
        scope: :shared,
        unique_name: "Manuk Engineer#ep13_2"
      }
    ]

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
      ctx = set_local(ctx, :alba, checkquest(ctx, 7080))

      if get_local(ctx, :alba, 0) == 0 or get_local(ctx, :alba, 0) == 1 do
        ctx = set_local(ctx, :time_chek, checkquest(ctx, 7080, :playtime))

        if get_local(ctx, :time_chek, 0) != 2 do
          ctx
          |> mes("[Manuk Engineer]")
          |> mes("Thank you for collecting the Enriched Bradium for me, it was very helpful.")
          |> mes("We've got more than enough for now though.")
          |> close()
        else
          ctx
          |> mes("[Manuk Engineer]")
          |> mes("Thank you for collecting the Enriched Bradium for me, it was very helpful.")
          |> mes("I hope you can help me again.")
          |> erasequest(7080)
          |> close()
        end
      else
        ctx = set_local(ctx, :alba2, checkquest(ctx, 7079))

        if get_local(ctx, :alba2, 0) == 0 or get_local(ctx, :alba2, 0) == 1 do
          if count_item(ctx, 6090) > 19 do
            ctx
            |> mes("[Manuk Engineer]")
            |> mes("Oh, that will do very well.")
            |> mes("On behalf of the Sapha, I extend our thanks to you.")
            |> mes("I hope you can help us again.")
            |> delitem(6090, 20)
            |> erasequest(7079)
            |> setquest(7080)
            |> getexp(40_000, 40_000)
            |> give_item(6080, 3)
            |> close()
          else
            ctx
            |> mes("[Manuk Engineer]")
            |> mes("What's up?")
            |> mes("You're not prepared yet.")
            |> close()
          end
        else
          {ctx, choice} =
            ctx
            |> mes("[Manuk Engineer]")
            |> mes("Hello.")
            |> mes("This is where we refine stones.")
            |> next()
            |> select(["About collecting stones.", "About the usage of stones."])

          case choice do
            1 ->
              {ctx, confirmation} =
                ctx
                |> mes("[Manuk Engineer]")
                |> mes("To prevent our bodies from becoming numb, we need Bradium.")
                |> mes(
                  "From the Bradium we can extract a special element that we need to survive."
                )
                |> next()
                |> mes("[Manuk Engineer]")
                |> mes("The mining industry is primary here since our lives depend on it.")
                |> mes("But the mine has become clogged.")
                |> next()
                |> mes("[Manuk Engineer]")
                |> mes("I've already heard that you guys are good soldiers.")
                |> mes(
                  "Would you mind terminating the Bradium Golem, and bringing back some Bradium for me?"
                )
                |> next()
                |> select(["Sure, I don't mind.", "Nope, I can't."])

              case confirmation do
                1 ->
                  ctx
                  |> mes("[Manuk Engineer]")
                  |> mes("Then take this mission.")
                  |> mes("Please hunt Bradium Golem and bring me 20 blended Bradium.")
                  |> setquest(7079)
                  |> close()

                2 ->
                  ctx
                  |> mes("[Manuk Engineer]")
                  |> mes("Oh, this is our fate.")
                  |> mes("How could I be so naive to depend on others?")
                  |> close()

                _ ->
                  ctx
              end

            2 ->
              ctx
              |> mes("[Manuk Engineer]")
              |> mes("We refine Bradium and extract special things from it.")
              |> mes("Then form that into an injection.")
              |> mes("When it is refined it is used to maintain our body cycles.")
              |> next()
              |> mes("[Manuk Engineer]")
              |> mes("That's why we are quite advanced in this industry.")
              |> mes("Other industries are also well developed... but...")
              |> next()
              |> mes("[Manuk Engineer]")
              |> mes("This is our top priority because it is crucial for our survival.")
              |> close()

            _ ->
              ctx
          end
        end
      end
    else
      ctx
      |> mes("[Manuk Engineer]")
      |> mes("Aweo wpe?")
      |> mes("Sdd psiem!")
      |> mes("Awq ouwn ksudh bud ds.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
