defmodule Aesir.ZoneServer.Content.Npc.Cities.Manuk.Benknee do
  @moduledoc """
  Shares a Manuk resident's remarks according to whether the visitor understands the local language.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "manuk",
        x: 188,
        y: 216,
        dir: 3,
        sprite: 449,
        name: "Benknee",
        scope: :shared,
        unique_name: "Benknee#ep13_2_1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if is_equipped(ctx, 2782) == 1 and get_char_var(ctx, :ep13_2_rhea, 0) == 100 do
      ctx
      |> mes("[Benknee]")
      |> mes("What brings you here?")
      |> mes("Are you a human?")
      |> mes("If you are human, you shouldn't be here.")
      |> next()
      |> mes("[Benknee]")
      |> mes("Jotunheim is a blessed and sacred place.")
      |> mes("We, Saphas will be standing with our own feet.")
      |> mes("And rise against oppression!")
      |> close()
    else
      ctx
      |> mes("[Benknee]")
      |> mes("Bdf sdio hs ioq")
      |> mes("Wfn is ao ps od jd")
      |> mes("No pip dd dow hso le")
      |> next()
      |> mes("[Benknee]")
      |> mes("Wsd oup nc xkh d")
      |> mes("Rww o jsd sp")
      |> mes("Yd aihd oa sd s dd")
      |> close()
    end
  end
end
