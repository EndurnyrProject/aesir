defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.TheSignQuest.SignThesign do
  @moduledoc """
  Displays the signs that introduce the quest.

  ## Behavior

  - Shows four illustrations and starts the quest if it has not yet begun.
  - Initializes the quest's shared settings.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Sign", scope: :shared, unique_name: "TheSign"},
      %{
        map: "prontera",
        x: 147,
        y: 305,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#prontera"
      },
      %{
        map: "geffen",
        x: 168,
        y: 175,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#geffen"
      },
      %{
        map: "morocc",
        x: 168,
        y: 265,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#morocc"
      },
      %{
        map: "payon",
        x: 160,
        y: 183,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#payon"
      },
      %{
        map: "aldebaran",
        x: 54,
        y: 223,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#aldebaran"
      },
      %{
        map: "alberta",
        x: 35,
        y: 241,
        dir: 0,
        sprite: 111,
        name: "Sign",
        scope: :shared,
        unique_name: "Sign#alberta"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    ctx =
      ctx
      |> cutin("sign_01", 4)
      |> mes("^3355FFNext^000000")
      |> next()
      |> cutin("sign_01", 255)
      |> cutin("sign_02", 4)
      |> mes("^3355FFNext^000000")
      |> next()
      |> cutin("sign_02", 255)
      |> cutin("sign_03", 4)
      |> mes("^3355FFNext^000000")
      |> next()
      |> cutin("sign_03", 255)
      |> cutin("sign_04", 4)

    ctx =
      if not Rathena.truthy?(get_char_var(ctx, :sign_q, 0)) do
        set_char_var(ctx, :sign_q, 1)
      else
        ctx
      end

    ctx |> mes("^3355FFClose^000000") |> close2() |> cutin("sign_04", 255)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    ctx
    |> set_server_var("signbmps", 0)
    |> set_server_var("signmazemonster", 0)
    |> set_server_var("timezonestring$", "^FF0000GMT^000000")
  end
end
