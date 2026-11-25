defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsMoscovia.Ptree do
  @moduledoc """
  Pointed trees provide branches for the wooden flute quest.

  ## Behavior

  - Collect a branch or suffer thorn damage; collected trees temporarily disappear.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "PTree", scope: :shared, unique_name: "PTree#rusmain"},
      %{
        map: "mosk_fild02",
        x: 151,
        y: 188,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus11"
      },
      %{
        map: "mosk_fild02",
        x: 160,
        y: 227,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus12"
      },
      %{
        map: "mosk_fild02",
        x: 160,
        y: 179,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus13"
      },
      %{
        map: "mosk_fild02",
        x: 142,
        y: 247,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus14"
      },
      %{
        map: "mosk_fild02",
        x: 149,
        y: 223,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus15"
      },
      %{
        map: "mosk_fild02",
        x: 114,
        y: 223,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus16"
      },
      %{
        map: "mosk_fild02",
        x: 101,
        y: 197,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus17"
      },
      %{
        map: "mosk_fild02",
        x: 125,
        y: 182,
        dir: 0,
        sprite: 111,
        name: "Pointed Tree",
        scope: :shared,
        unique_name: "Pointed Tree#rus18"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer60000", ctx) do
    ev_ontimer60000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :rhea_rus_ring, 0) == 6 and count_item(ctx, 7882) < 50 do
      if Enum.random(1..3) == 2 do
        ctx
        |> mes("- I avoid the thorns and -")
        |> mes("- cut off a branch!! -")
        |> give_item(7882, 1)
        |> donpcevent(Rathena.concat(strnpcinfo(ctx, 0), "::OnDisable"))
        |> close()
      else
        ctx
        |> mes("- My hand is pricked by thorns! -")
        |> specialeffect2(:hit2)
        |> percent_heal(hp: -5, sp: 0)
        |> close()
      end
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ondisable(ctx) do
    ctx |> initnpctimer() |> disablenpc()
  end

  def ev_ontimer60000(ctx) do
    ev_onenable(ctx)
  end

  def ev_onenable(ctx) do
    ctx |> stopnpctimer() |> enablenpc()
  end
end
