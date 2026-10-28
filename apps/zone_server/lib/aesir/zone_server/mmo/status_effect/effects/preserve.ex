defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Preserve do
  @moduledoc """
  Preserve (SC_PRESERVE).

  In renewal and pre-renewal, while it holds (10 minutes) Plagiarism copies no
  skill, so the skill already copied is kept. It is not saved at logout and
  ends under Hermode; Dispel and buff clearing end it.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_preserve,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    no_save: true,
    icon: :preserve
end
