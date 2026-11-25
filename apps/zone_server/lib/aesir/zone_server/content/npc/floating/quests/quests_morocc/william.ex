defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMorocc.William do
  @moduledoc """
  William makes Stop Post ornaments.

  ## Behavior

  - He trades a Stop Post for trunks, dye and zeny.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "William", scope: :shared},
      %{
        map: "moc_ruins",
        x: 113,
        y: 181,
        dir: 4,
        sprite: 89,
        name: "William",
        scope: :pre_renewal,
        unique_name: "William#moc"
      },
      %{
        map: "morocc",
        x: 152,
        y: 167,
        dir: 4,
        sprite: 89,
        name: "William",
        scope: :renewal,
        unique_name: "William#moc"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[William]")
      |> mes("Welcome to")
      |> mes("MacMillan's ^3355FFPost^000000 Workshop.")
      |> next()
      |> mes("[William]")
      |> mes(
        "My family, the MacMillan Clan, has been producing Professional Traffic Signal Posts for more than 250 years. Nowadays, we are booking Special Orders for our unique ornament, ^3355FFStop Post^000000."
      )
      |> next()
      |> select(["Could I order one ^3355FFStop Post^000000?", "Nah..."])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[William]")
          |> mes(
            "This unique ornament, ^3355FFStop Post^000000, is a traffic signal on the road, and doubles as a hair ornament! This, we solemnly promise on the strength of a 100-year guarantee."
          )
          |> next()
          |> mes("[William]")
          |> mes(
            "To produce a ^3355FFStop Post^000000, we need ^3355FF91100 Zeny^000000, ^3355FF50 Trunk^000000 and ^3355FF1 Black Dyestuffs^000000."
          )
          |> next()

        if count_item(ctx, 1019) > 49 and count_item(ctx, 983) > 0 and zeny(ctx) > 91099 do
          ctx
          |> delitem(1019, 50)
          |> delitem(983, 1)
          |> pay_zeny(91100)
          |> mes("[William]")
          |> mes("Here you are~!")
          |> mes("This ^3355FFStop Post^000000 has")
          |> mes("been especially made")
          |> mes("just for you!")
          |> mes("Thank you for stopping by!")
          |> mes("...Get the joke?")
          |> give_item(2272, 1)
          |> close()
        else
          ctx
          |> mes("[William]")
          |> mes("So...")
          |> mes("When you get those items, swing on by and we'll give you a Stop Post.")
          |> close()
        end

      2 ->
        ctx
        |> mes("[William]")
        |> mes(
          "Anyway, thank you for coming by 'MacMillan's Workshop.' But think about buying something next time, will ya?"
        )
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
