defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsBrasilis.Puppy do
  @moduledoc """
  The missing puppies advance Angelo's rescue quest.

  ## Behavior

  - Counts found puppies, advances the quest and reveals another puppy.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Puppy", unique_name: "Puppy#bra"},
      %{
        map: "bra_fild01",
        x: 98,
        y: 96,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#a1"
      },
      %{
        map: "bra_fild01",
        x: 59,
        y: 116,
        dir: 5,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#a2"
      },
      %{
        map: "bra_fild01",
        x: 62,
        y: 142,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#a3"
      },
      %{
        map: "bra_fild01",
        x: 80,
        y: 163,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#b1"
      },
      %{
        map: "bra_fild01",
        x: 73,
        y: 210,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#b2"
      },
      %{
        map: "bra_fild01",
        x: 80,
        y: 210,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#b3"
      },
      %{
        map: "bra_fild01",
        x: 38,
        y: 235,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#c1"
      },
      %{
        map: "bra_fild01",
        x: 307,
        y: 64,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#c2"
      },
      %{
        map: "bra_fild01",
        x: 260,
        y: 60,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#c3"
      },
      %{
        map: "bra_fild01",
        x: 234,
        y: 101,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#d1"
      },
      %{
        map: "bra_fild01",
        x: 200,
        y: 84,
        dir: 3,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#d2"
      },
      %{
        map: "bra_fild01",
        x: 176,
        y: 63,
        dir: 5,
        sprite: 81,
        name: "Puppy",
        scope: :shared,
        unique_name: "Puppy#d3"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx) do
    if not Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 2), "1")) do
      hideonnpc(ctx, strnpcinfo(ctx, 0))
    else
      ctx
    end
  end

  def on_event("OnEnable", ctx), do: hideoffnpc(ctx, strnpcinfo(ctx, 0))
  def on_event("OnDisable", ctx), do: hideonnpc(ctx, strnpcinfo(ctx, 0))

  @impl true
  def on_talk(ctx) do
    ctx = ctx |> mes("[Puppy]") |> mes("bow! wow wow!")

    ctx =
      if checkquest(ctx, 9030) == 1 and get_char_var(ctx, :brazil_kid, 0) < 3 do
        find_puppy(ctx)
      else
        ctx
      end

    close(ctx)
  end

  defp find_puppy(ctx) do
    ctx = next(ctx)
    ctx = set_char_var(ctx, :brazil_kid, get_char_var(ctx, :brazil_kid, 0) + 1)
    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx =
      if get_char_var(ctx, :brazil_kid, 0) == 3 do
        ctx
        |> mes("Good. I found all 3 puppies.")
        |> mes("Now I need to go tell Angelo.")
        |> set_char_var(:brazil_kid, 0)
        |> erasequest(9030)
        |> setquest(9031)
      else
        ctx |> mes("Ah... who's a good puppy?") |> mes("Ok, where are the others?")
      end

    alternatives =
      cond do
        Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 2), "1")) -> [2, 3]
        Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 2), "2")) -> [1, 3]
        true -> [1, 2]
      end

    ctx = set_local(ctx, :i, alternatives)

    ctx =
      donpcevent(
        ctx,
        Rathena.concat(
          Rathena.concat(
            Rathena.concat("Puppy#", Rathena.charat(strnpcinfo(ctx, 2), 0)),
            Enum.at(get_local(ctx, :i, []), :rand.uniform(2) - 1, 0)
          ),
          "::OnEnable"
        )
      )

    hideonnpc(ctx, strnpcinfo(ctx, 0))
  end
end
